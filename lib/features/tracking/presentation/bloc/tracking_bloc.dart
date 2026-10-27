import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_permission_service.dart';
import '../../../../core/utils/haversine.dart';
import '../../domain/entities/location_point.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/usecases/cluster_markers_usecase.dart';
import 'tracking_event.dart';
import 'tracking_state.dart';

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final ITrackingRepository trackingRepository;
  final ILocationPermissionService permissionService;
  final ClusterMarkersUseCase clusterUseCase;

  StreamSubscription<LocationPoint>? _locationSubscription;
  List<ClusterDeliveryItem> _activeDeliveryZones = [];

  TrackingBloc({
    required this.trackingRepository,
    required this.permissionService,
    required this.clusterUseCase,
  }) : super(const TrackingInitial()) {
    on<InitializeTrackingEvent>(_onInitialize);
    on<LocationUpdatedEvent>(_onLocationUpdated);
    on<ToggleBackgroundTrackingEvent>(_onToggleBackgroundTracking);
    on<UpdateMapZoomEvent>(_onUpdateMapZoom);
    on<RequestLocationPermissionEvent>(_onRequestPermission);
    on<RecheckPermissionEvent>(_onRecheckPermission);
    on<OpenAppSettingsEvent>(_onOpenAppSettings);
    on<OpenLocationSettingsEvent>(_onOpenLocationSettings);
  }

  List<ClusterDeliveryItem> _generateNearbyDeliveryZones(double lat, double lng) {
    return [
      ClusterDeliveryItem(
        id: 'DEL-101',
        title: 'Stop #101 - Primary Logistics Hub',
        address: 'Sector Drop-off Depot Alpha',
        latitude: lat + 0.003,
        longitude: lng + 0.004,
      ),
      ClusterDeliveryItem(
        id: 'DEL-102',
        title: 'Stop #102 - Residential Complex',
        address: 'Apartment Tower 4, Lane 2',
        latitude: lat + 0.0036,
        longitude: lng + 0.0043,
      ),
      ClusterDeliveryItem(
        id: 'DEL-103',
        title: 'Stop #103 - Commercial Center',
        address: 'Business Park Gate 1',
        latitude: lat - 0.004,
        longitude: lng + 0.005,
      ),
      ClusterDeliveryItem(
        id: 'DEL-104',
        title: 'Stop #104 - Express Pharmacy',
        address: 'Main Market Complex Shop 8',
        latitude: lat - 0.002,
        longitude: lng - 0.003,
      ),
      ClusterDeliveryItem(
        id: 'DEL-105',
        title: 'Stop #105 - Retail Warehouse',
        address: 'Logistics Terminal Bay C',
        latitude: lat + 0.007,
        longitude: lng - 0.006,
      ),
    ];
  }

  Future<void> _onInitialize(
    InitializeTrackingEvent event,
    Emitter<TrackingState> emit,
  ) async {
    if (state is TrackingLoaded) return;
    if (state is TrackingLoading) return;

    emit(const TrackingLoading());

    final permissionStatus = await permissionService.checkPermission();
    var currentStatus = permissionStatus;

    if (currentStatus == LocationAccessStatus.denied) {
      try {
        currentStatus = await permissionService
            .requestForegroundPermission()
            .timeout(const Duration(seconds: 45), onTimeout: () {
          return LocationAccessStatus.denied;
        });
      } catch (_) {
        currentStatus = LocationAccessStatus.denied;
      }
    }

    if (currentStatus != LocationAccessStatus.granted) {
      final isPerm = currentStatus == LocationAccessStatus.permanentlyDenied;
      final isServiceDisabled = currentStatus == LocationAccessStatus.serviceDisabled;

      const fallbackLat = 28.6139;
      const fallbackLng = 77.2090;
      _activeDeliveryZones = _generateNearbyDeliveryZones(fallbackLat, fallbackLng);

      final clusters = clusterUseCase.execute(
        items: _activeDeliveryZones,
        zoomLevel: 14.5,
      );

      // Cynosure M1 requirement: Graceful degradation (the map must still load without the marker)
      emit(TrackingLoaded(
        currentLocation: null,
        locationHistory: const [],
        clusterMarkers: clusters,
        totalDistanceMeters: 0.0,
        isBackgroundTrackingActive: false,
        currentZoom: 14.5,
        gpsWarning: isServiceDisabled
            ? 'Location service is disabled on device. Turn on GPS to see your live position.'
            : (isPerm
                ? 'Location permission permanently denied. Enable in App Settings.'
                : 'Location permission required for live tracking.'),
        isGpsDisabled: isServiceDisabled,
        isPermissionDenied: !isServiceDisabled,
      ));
      return;
    }

    try {
      final initialPosition = await trackingRepository.getCurrentLocation().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          return LocationPoint(
            latitude: 28.6139,
            longitude: 77.2090,
            timestamp: DateTime.now(),
          );
        },
      );
      final isBgActive = await trackingRepository.isBackgroundTrackingActive().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );

      _activeDeliveryZones = _generateNearbyDeliveryZones(
        initialPosition.latitude,
        initialPosition.longitude,
      );

      final clusters = clusterUseCase.execute(
        items: _activeDeliveryZones,
        zoomLevel: 14.5,
      );

      emit(TrackingLoaded(
        currentLocation: initialPosition,
        locationHistory: [initialPosition],
        clusterMarkers: clusters,
        totalDistanceMeters: 0.0,
        isBackgroundTrackingActive: isBgActive,
        currentZoom: 14.5,
      ));

      await _locationSubscription?.cancel();
      _locationSubscription = trackingRepository
          .getTrackingStream(
            intervalSeconds: AppConstants.foregroundTrackingInterval,
            distanceFilter: AppConstants.minDistanceFilterMeters,
          )
          .listen(
            (point) {
              add(LocationUpdatedEvent(point));
            },
            onError: (dynamic error) {
              add(const RecheckPermissionEvent());
            },
            cancelOnError: false,
          );
    } catch (e) {
      const fallbackLat = 28.6139;
      const fallbackLng = 77.2090;
      _activeDeliveryZones = _generateNearbyDeliveryZones(fallbackLat, fallbackLng);

      final clusters = clusterUseCase.execute(
        items: _activeDeliveryZones,
        zoomLevel: 14.5,
      );

      final fallbackPoint = LocationPoint(
        latitude: fallbackLat,
        longitude: fallbackLng,
        timestamp: DateTime.now(),
      );

      emit(TrackingLoaded(
        currentLocation: fallbackPoint,
        locationHistory: [fallbackPoint],
        clusterMarkers: clusters,
        totalDistanceMeters: 0.0,
        isBackgroundTrackingActive: false,
        currentZoom: 14.5,
      ));
    }
  }

  void _onLocationUpdated(
    LocationUpdatedEvent event,
    Emitter<TrackingState> emit,
  ) {
    if (state is! TrackingLoaded) return;
    final currentState = state as TrackingLoaded;

    double addedDistance = 0.0;
    if (currentState.currentLocation != null) {
      addedDistance = Haversine.calculateDistanceInMeters(
        startLatitude: currentState.currentLocation!.latitude,
        startLongitude: currentState.currentLocation!.longitude,
        endLatitude: event.point.latitude,
        endLongitude: event.point.longitude,
      );
    }

    final updatedHistory = List<LocationPoint>.from(currentState.locationHistory)..add(event.point);

    emit(currentState.copyWith(
      currentLocation: event.point,
      locationHistory: updatedHistory,
      totalDistanceMeters: currentState.totalDistanceMeters + addedDistance,
    ));
  }

  Future<void> _onToggleBackgroundTracking(
    ToggleBackgroundTrackingEvent event,
    Emitter<TrackingState> emit,
  ) async {
    if (state is! TrackingLoaded) return;
    final currentState = state as TrackingLoaded;

    if (currentState.isBackgroundTrackingActive) {
      await trackingRepository.stopBackgroundTracking();
      emit(currentState.copyWith(isBackgroundTrackingActive: false));
    } else {
      final success = await trackingRepository.startBackgroundTracking();
      emit(currentState.copyWith(isBackgroundTrackingActive: success));
    }
  }

  void _onUpdateMapZoom(
    UpdateMapZoomEvent event,
    Emitter<TrackingState> emit,
  ) {
    if (state is! TrackingLoaded) return;
    final currentState = state as TrackingLoaded;

    final updatedClusters = clusterUseCase.execute(
      items: _activeDeliveryZones,
      zoomLevel: event.zoom,
    );

    emit(currentState.copyWith(
      currentZoom: event.zoom,
      clusterMarkers: updatedClusters,
    ));
  }

  Future<void> _onRequestPermission(
    RequestLocationPermissionEvent event,
    Emitter<TrackingState> emit,
  ) async {
    final status = await permissionService.requestForegroundPermission();
    if (status == LocationAccessStatus.granted) {
      add(const RecheckPermissionEvent());
    } else {
      final isPerm = status == LocationAccessStatus.permanentlyDenied;
      final isServiceDisabled = status == LocationAccessStatus.serviceDisabled;
      if (state is TrackingLoaded) {
        emit((state as TrackingLoaded).copyWith(
          gpsWarning: isServiceDisabled
              ? 'Location service is disabled on device. Turn on GPS to see your live position.'
              : (isPerm
                  ? 'Location permission permanently denied. Enable in App Settings.'
                  : 'Location permission required for live tracking.'),
          isGpsDisabled: isServiceDisabled,
          isPermissionDenied: !isServiceDisabled,
        ));
      }
    }
  }

  Future<void> _onRecheckPermission(
    RecheckPermissionEvent event,
    Emitter<TrackingState> emit,
  ) async {
    final permissionStatus = await permissionService.checkPermission();
    if (permissionStatus == LocationAccessStatus.granted) {
      if (state is TrackingLoaded && (state as TrackingLoaded).currentLocation != null) {
        emit((state as TrackingLoaded).copyWith(
          gpsWarning: null,
          isGpsDisabled: false,
          isPermissionDenied: false,
        ));
        return;
      }

      try {
        final initialPosition = await trackingRepository.getCurrentLocation().timeout(
          const Duration(seconds: 5),
          onTimeout: () => LocationPoint(
            latitude: 28.6139,
            longitude: 77.2090,
            timestamp: DateTime.now(),
          ),
        );
        _activeDeliveryZones = _generateNearbyDeliveryZones(
          initialPosition.latitude,
          initialPosition.longitude,
        );
        final clusters = clusterUseCase.execute(
          items: _activeDeliveryZones,
          zoomLevel: 14.5,
        );

        emit(TrackingLoaded(
          currentLocation: initialPosition,
          locationHistory: [initialPosition],
          clusterMarkers: clusters,
          totalDistanceMeters: 0.0,
          isBackgroundTrackingActive: false,
          currentZoom: 14.5,
          gpsWarning: null,
          isGpsDisabled: false,
          isPermissionDenied: false,
        ));

        await _locationSubscription?.cancel();
        _locationSubscription = trackingRepository
            .getTrackingStream(
              intervalSeconds: AppConstants.foregroundTrackingInterval,
              distanceFilter: AppConstants.minDistanceFilterMeters,
            )
            .listen(
              (point) {
                add(LocationUpdatedEvent(point));
              },
              onError: (dynamic error) {
                add(const RecheckPermissionEvent());
              },
              cancelOnError: false,
            );
      } catch (_) {}
    } else {
      final isPerm = permissionStatus == LocationAccessStatus.permanentlyDenied;
      final isServiceDisabled = permissionStatus == LocationAccessStatus.serviceDisabled;
      if (state is TrackingLoaded) {
        emit((state as TrackingLoaded).copyWith(
          gpsWarning: isServiceDisabled
              ? 'Location service is disabled on device. Turn on GPS to see your live position.'
              : (isPerm
                  ? 'Location permission permanently denied. Enable in App Settings.'
                  : 'Location permission required for live tracking.'),
          isGpsDisabled: isServiceDisabled,
          isPermissionDenied: !isServiceDisabled,
        ));
      }
    }
  }

  Future<void> _onOpenAppSettings(
    OpenAppSettingsEvent event,
    Emitter<TrackingState> emit,
  ) async {
    await permissionService.openAppSettings();
  }

  Future<void> _onOpenLocationSettings(
    OpenLocationSettingsEvent event,
    Emitter<TrackingState> emit,
  ) async {
    await permissionService.openLocationSettings();
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}
