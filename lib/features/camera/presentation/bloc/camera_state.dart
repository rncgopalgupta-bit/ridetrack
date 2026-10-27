import 'package:equatable/equatable.dart';
import 'package:ridetrack/features/camera/domain/entities/pod_photo.dart';

abstract class CameraState extends Equatable {
  const CameraState();

  @override
  List<Object?> get props => [];
}

class CameraInitial extends CameraState {
  const CameraInitial();
}

class CameraReady extends CameraState {
  const CameraReady();
}

class CameraProcessingPhoto extends CameraState {
  const CameraProcessingPhoto();
}

class CameraPhotoCaptured extends CameraState {
  final PodPhoto photo;

  const CameraPhotoCaptured(this.photo);

  @override
  List<Object?> get props => [photo];
}

class GalleryLoaded extends CameraState {
  final List<PodPhoto> photos;

  const GalleryLoaded(this.photos);

  @override
  List<Object?> get props => [photos];
}

class CameraError extends CameraState {
  final String message;

  const CameraError(this.message);

  @override
  List<Object?> get props => [message];
}
