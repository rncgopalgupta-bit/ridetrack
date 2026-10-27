import 'package:equatable/equatable.dart';

abstract class CameraEvent extends Equatable {
  const CameraEvent();

  @override
  List<Object?> get props => [];
}

class InitializeCameraEvent extends CameraEvent {
  const InitializeCameraEvent();
}

class CapturePhotoEvent extends CameraEvent {
  final String rawTempPath;
  final double latitude;
  final double longitude;
  final String? deliveryId;

  const CapturePhotoEvent({
    required this.rawTempPath,
    required this.latitude,
    required this.longitude,
    this.deliveryId,
  });

  @override
  List<Object?> get props => [rawTempPath, latitude, longitude, deliveryId];
}

class LoadGalleryEvent extends CameraEvent {
  const LoadGalleryEvent();
}

class DeletePhotoEvent extends CameraEvent {
  final String photoId;

  const DeletePhotoEvent(this.photoId);

  @override
  List<Object?> get props => [photoId];
}
