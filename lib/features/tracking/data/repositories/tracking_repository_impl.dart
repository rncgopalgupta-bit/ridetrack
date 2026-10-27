import 'package:ridetrack/core/services/background_tracking_service.dart';
import 'package:ridetrack/features/tracking/domain/entities/location_point.dart';
import 'package:ridetrack/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:ridetrack/features/tracking/data/datasources/location_datasource.dart';

class TrackingRepositoryImpl implements ITrackingRepository {
  final ILocationDataSource locationDataSource;

  TrackingRepositoryImpl({required this.locationDataSource});

  @override
  Future<LocationPoint> getCurrentLocation() {
    return locationDataSource.getCurrentLocation();
  }

  @override
  Stream<LocationPoint> getTrackingStream({
    required int intervalSeconds,
    required double distanceFilter,
  }) {
    return locationDataSource.getLocationStream(
      intervalSeconds: intervalSeconds,
      distanceFilter: distanceFilter,
    );
  }

  @override
  Future<bool> startBackgroundTracking() {
    return BackgroundTrackingService.startService();
  }

  @override
  Future<bool> stopBackgroundTracking() {
    return BackgroundTrackingService.stopService();
  }

  @override
  Future<bool> isBackgroundTrackingActive() {
    return BackgroundTrackingService.isRunning();
  }
}
