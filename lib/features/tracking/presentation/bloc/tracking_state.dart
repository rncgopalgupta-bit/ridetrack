import 'package:equatable/equatable.dart';
import '../../domain/entities/cluster_marker.dart';
import '../../domain/entities/location_point.dart';

abstract class TrackingState extends Equatable {
  const TrackingState();

  @override
  List<Object?> get props => [];
}

class TrackingInitial extends TrackingState {
  const TrackingInitial();
}

class TrackingLoading extends TrackingState {
  const TrackingLoading();
}

class TrackingPermissionDenied extends TrackingState {
  final bool isPermanentlyDenied;
  final String message;

  const TrackingPermissionDenied({
    required this.isPermanentlyDenied,
    required this.message,
  });

  @override
  List<Object?> get props => [isPermanentlyDenied, message];
}

class TrackingLoaded extends TrackingState {
  final LocationPoint? currentLocation;
  final List<LocationPoint> locationHistory;
  final List<ClusterMarker> clusterMarkers;
  final double totalDistanceMeters;
  final bool isBackgroundTrackingActive;
  final double currentZoom;
  final String? gpsWarning;
  final bool isGpsDisabled;
  final bool isPermissionDenied;

  const TrackingLoaded({
    this.currentLocation,
    this.locationHistory = const [],
    this.clusterMarkers = const [],
    this.totalDistanceMeters = 0.0,
    this.isBackgroundTrackingActive = false,
    this.currentZoom = 14.0,
    this.gpsWarning,
    this.isGpsDisabled = false,
    this.isPermissionDenied = false,
  });

  TrackingLoaded copyWith({
    LocationPoint? currentLocation,
    bool clearCurrentLocation = false,
    List<LocationPoint>? locationHistory,
    List<ClusterMarker>? clusterMarkers,
    double? totalDistanceMeters,
    bool? isBackgroundTrackingActive,
    double? currentZoom,
    String? gpsWarning,
    bool clearGpsWarning = false,
    bool? isGpsDisabled,
    bool? isPermissionDenied,
  }) {
    return TrackingLoaded(
      currentLocation: clearCurrentLocation ? null : (currentLocation ?? this.currentLocation),
      locationHistory: locationHistory ?? this.locationHistory,
      clusterMarkers: clusterMarkers ?? this.clusterMarkers,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      isBackgroundTrackingActive: isBackgroundTrackingActive ?? this.isBackgroundTrackingActive,
      currentZoom: currentZoom ?? this.currentZoom,
      gpsWarning: clearGpsWarning ? null : (gpsWarning ?? this.gpsWarning),
      isGpsDisabled: isGpsDisabled ?? this.isGpsDisabled,
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
    );
  }

  @override
  List<Object?> get props => [
        currentLocation,
        locationHistory,
        clusterMarkers,
        totalDistanceMeters,
        isBackgroundTrackingActive,
        currentZoom,
        gpsWarning,
        isGpsDisabled,
        isPermissionDenied,
      ];
}

class TrackingError extends TrackingState {
  final String message;

  const TrackingError(this.message);

  @override
  List<Object?> get props => [message];
}
