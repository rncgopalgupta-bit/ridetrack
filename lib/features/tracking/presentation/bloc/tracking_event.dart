import 'package:equatable/equatable.dart';
import '../../domain/entities/location_point.dart';

abstract class TrackingEvent extends Equatable {
  const TrackingEvent();

  @override
  List<Object?> get props => [];
}

class InitializeTrackingEvent extends TrackingEvent {
  const InitializeTrackingEvent();
}

class LocationUpdatedEvent extends TrackingEvent {
  final LocationPoint point;

  const LocationUpdatedEvent(this.point);

  @override
  List<Object?> get props => [point];
}

class ToggleBackgroundTrackingEvent extends TrackingEvent {
  const ToggleBackgroundTrackingEvent();
}

class UpdateMapZoomEvent extends TrackingEvent {
  final double zoom;

  const UpdateMapZoomEvent(this.zoom);

  @override
  List<Object?> get props => [zoom];
}

class RequestLocationPermissionEvent extends TrackingEvent {
  const RequestLocationPermissionEvent();
}

class RecheckPermissionEvent extends TrackingEvent {
  const RecheckPermissionEvent();
}

class OpenAppSettingsEvent extends TrackingEvent {
  const OpenAppSettingsEvent();
}

class OpenLocationSettingsEvent extends TrackingEvent {
  const OpenLocationSettingsEvent();
}
