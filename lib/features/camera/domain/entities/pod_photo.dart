import 'package:equatable/equatable.dart';

class PodPhoto extends Equatable {
  final String id;
  final String fullImagePath;
  final String thumbnailPath;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final int fileSizeBytes;

  const PodPhoto({
    required this.id,
    required this.fullImagePath,
    required this.thumbnailPath,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.fileSizeBytes,
  });

  @override
  List<Object?> get props => [
        id,
        fullImagePath,
        thumbnailPath,
        timestamp,
        latitude,
        longitude,
        fileSizeBytes,
      ];
}
