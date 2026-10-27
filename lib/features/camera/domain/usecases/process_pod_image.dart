import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../entities/pod_photo.dart';

class ImageProcessingParams {
  final String rawFilePath;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String destinationDirectory;
  final String? deliveryId;

  const ImageProcessingParams({
    required this.rawFilePath,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.destinationDirectory,
    this.deliveryId,
  });
}

class ProcessPodImageUseCase {
  Future<PodPhoto> execute({
    required String rawFilePath,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    String? deliveryId,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final podDir = Directory(p.join(docsDir.path, 'pod_photos'));
    if (!await podDir.exists()) {
      await podDir.create(recursive: true);
    }

    final params = ImageProcessingParams(
      rawFilePath: rawFilePath,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      destinationDirectory: podDir.path,
      deliveryId: deliveryId,
    );

    // Offload image decoding, EXIF rotation bake, text stamping, and compression to background Isolate
    return await compute(_processImageInIsolate, params);
  }

  static PodPhoto _processImageInIsolate(ImageProcessingParams params) {
    final rawFile = File(params.rawFilePath);
    final rawBytes = rawFile.readAsBytesSync();

    final img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw Exception('Failed to decode raw camera image buffer.');
    }

    // Fix EXIF orientation: Mobile camera sensors are physically mounted in landscape
    // bakeOrientation transforms the pixel matrix to match the orientation tag permanently
    final img.Image orientedImage = img.bakeOrientation(decoded);

    // Overlay GPS coordinates and timestamp
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(params.timestamp);
    final stampText = 'GPS: ${params.latitude.toStringAsFixed(5)}, ${params.longitude.toStringAsFixed(5)}  |  $formattedDate';

    // Draw background contrast bar at bottom of photo
    final int barHeight = (orientedImage.height * 0.05).clamp(40, 100).toInt();
    final int startY = orientedImage.height - barHeight;

    img.fillRect(
      orientedImage,
      x1: 0,
      y1: startY,
      x2: orientedImage.width,
      y2: orientedImage.height,
      color: img.ColorRgba8(0, 0, 0, 160),
    );

    // Draw text overlay on the contrast bar
    img.drawString(
      orientedImage,
      stampText,
      font: img.arial24,
      x: 20,
      y: startY + (barHeight ~/ 4),
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    final String photoId = const Uuid().v4();
    final String prefix = params.deliveryId != null ? 'delivery_${params.deliveryId}_' : 'pod_';
    final String fullImagePath = p.join(params.destinationDirectory, '$prefix$photoId.jpg');
    final String thumbnailPath = p.join(params.destinationDirectory, 'thumb_$prefix$photoId.jpg');

    // Compress full image (80% quality JPEG)
    final compressedJpg = img.encodeJpg(orientedImage, quality: 80);
    File(fullImagePath).writeAsBytesSync(compressedJpg);

    // Generate low-memory thumbnail (max width 300px) for budget 1.5GB RAM device list views
    final img.Image thumbnail = img.copyResize(orientedImage, width: 300);
    final thumbJpg = img.encodeJpg(thumbnail, quality: 70);
    File(thumbnailPath).writeAsBytesSync(thumbJpg);

    // Clean up temporary raw camera file
    try {
      if (rawFile.existsSync()) {
        rawFile.deleteSync();
      }
    } catch (_) {}

    return PodPhoto(
      id: photoId,
      fullImagePath: fullImagePath,
      thumbnailPath: thumbnailPath,
      timestamp: params.timestamp,
      latitude: params.latitude,
      longitude: params.longitude,
      fileSizeBytes: compressedJpg.length,
    );
  }
}
