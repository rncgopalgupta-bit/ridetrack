import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:ridetrack/features/camera/domain/entities/pod_photo.dart';
import 'package:ridetrack/features/camera/domain/usecases/process_pod_image.dart';
import 'package:ridetrack/features/delivery_sync/data/datasources/delivery_local_datasource.dart';
import 'camera_event.dart';
import 'camera_state.dart';

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  final ProcessPodImageUseCase processImageUseCase;
  final IDeliveryLocalDataSource deliveryLocalDataSource;
  final List<PodPhoto> _photos = [];

  CameraBloc({
    required this.processImageUseCase,
    required this.deliveryLocalDataSource,
  }) : super(const CameraInitial()) {
    on<InitializeCameraEvent>(_onInitializeCamera);
    on<CapturePhotoEvent>(_onCapturePhoto);
    on<LoadGalleryEvent>(_onLoadGallery);
    on<DeletePhotoEvent>(_onDeletePhoto);
  }

  void _onInitializeCamera(InitializeCameraEvent event, Emitter<CameraState> emit) {
    emit(const CameraReady());
  }

  Future<void> _onCapturePhoto(CapturePhotoEvent event, Emitter<CameraState> emit) async {
    emit(const CameraProcessingPhoto());

    try {
      final podPhoto = await processImageUseCase.execute(
        rawFilePath: event.rawTempPath,
        latitude: event.latitude,
        longitude: event.longitude,
        timestamp: DateTime.now(),
        deliveryId: event.deliveryId,
      );

      // Only add directly to in-memory gallery if captured standalone (not pending delivery completion)
      if (event.deliveryId == null) {
        _photos.insert(0, podPhoto);
      }

      emit(CameraPhotoCaptured(podPhoto));
      emit(GalleryLoaded(List.unmodifiable(_photos)));
    } catch (e) {
      emit(CameraError('Failed to process image: ${e.toString()}'));
    }
  }

  Future<void> _onLoadGallery(LoadGalleryEvent event, Emitter<CameraState> emit) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final podDir = Directory(p.join(docsDir.path, 'pod_photos'));

      if (!await podDir.exists()) {
        await podDir.create(recursive: true);
        _photos.clear();
        emit(const GalleryLoaded([]));
        return;
      }

      // Query local SQLite deliveries to ensure only verified completed photos appear in the gallery
      final deliveries = await deliveryLocalDataSource.getAllDeliveries();
      
      // Verified photo basenames from completed deliveries
      final completedPhotoBasenames = deliveries
          .where((d) => d.status == 'completed' && d.photoProofPath != null)
          .map((d) => p.basename(d.photoProofPath!))
          .toSet();

      final completedDeliveryIds = deliveries
          .where((d) => d.status == 'completed')
          .map((d) => d.id)
          .toSet();

      final files = podDir.listSync().whereType<File>().toList();
      final fullImages = files.where((f) {
        final name = p.basename(f.path);
        return (name.startsWith('pod_') || name.startsWith('delivery_')) &&
            !name.startsWith('thumb_');
      }).toList();

      _photos.clear();
      for (final fullImg in fullImages) {
        final basename = p.basename(fullImg.path);

        if (basename.startsWith('delivery_')) {
          // A delivery photo is only valid if it matches the verified photoProofPath of a completed delivery
          if (!completedPhotoBasenames.contains(basename)) {
            final parts = basename.split('_');
            // If the delivery is already completed, any older photo with this delivery ID is an abandoned retake attempt
            if (parts.length >= 3 && completedDeliveryIds.contains(parts[1])) {
              try {
                if (fullImg.existsSync()) fullImg.deleteSync();
                final thumbPath = p.join(podDir.path, 'thumb_$basename');
                final thumbFile = File(thumbPath);
                if (thumbFile.existsSync()) thumbFile.deleteSync();
              } catch (_) {}
            }
            continue;
          }
        }

        final id = p.basenameWithoutExtension(fullImg.path);
        final thumbPath = p.join(podDir.path, 'thumb_$basename');
        final stat = fullImg.statSync();

        _photos.add(PodPhoto(
          id: id,
          fullImagePath: fullImg.path,
          thumbnailPath: File(thumbPath).existsSync() ? thumbPath : fullImg.path,
          timestamp: stat.modified,
          latitude: 28.6139,
          longitude: 77.2090,
          fileSizeBytes: stat.size,
        ));
      }

      _photos.sort((PodPhoto a, PodPhoto b) => b.timestamp.compareTo(a.timestamp));
      emit(GalleryLoaded(List.unmodifiable(_photos)));
    } catch (e) {
      emit(CameraError('Failed to load photo gallery: ${e.toString()}'));
    }
  }

  Future<void> _onDeletePhoto(DeletePhotoEvent event, Emitter<CameraState> emit) async {
    try {
      final index = _photos.indexWhere((PodPhoto p) => p.id == event.photoId);
      if (index != -1) {
        final photo = _photos[index];
        final fullFile = File(photo.fullImagePath);
        final thumbFile = File(photo.thumbnailPath);

        if (await fullFile.exists()) await fullFile.delete();
        if (await thumbFile.exists()) await thumbFile.delete();

        _photos.removeAt(index);
      }
      emit(GalleryLoaded(List.unmodifiable(_photos)));
    } catch (e) {
      emit(CameraError('Failed to delete photo: ${e.toString()}'));
    }
  }
}
