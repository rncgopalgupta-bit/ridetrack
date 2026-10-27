import '../entities/location_point.dart';

abstract class ITrackingRepository {
  Future<LocationPoint> getCurrentLocation();
  Stream<LocationPoint> getTrackingStream({required int intervalSeconds, required double distanceFilter});
  Future<bool> startBackgroundTracking();
  Future<bool> stopBackgroundTracking();
  Future<bool> isBackgroundTrackingActive();
}
