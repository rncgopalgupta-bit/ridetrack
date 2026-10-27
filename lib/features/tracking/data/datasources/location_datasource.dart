import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/location_point.dart';

abstract class ILocationDataSource {
  Future<LocationPoint> getCurrentLocation();
  Stream<LocationPoint> getLocationStream({required int intervalSeconds, required double distanceFilter});
}

class LocationDataSource implements ILocationDataSource {
  @override
  Future<LocationPoint> getCurrentLocation() async {
    Position? position;
    try {
      position = await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
    } catch (_) {}

    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        ).timeout(
          const Duration(seconds: 4),
          onTimeout: () => throw TimeoutException('Location fix timeout'),
        );
      } catch (_) {
        position = Position(
          latitude: 28.6139,
          longitude: 77.2090,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      }
    }

    return LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      timestamp: position.timestamp,
    );
  }

  @override
  Stream<LocationPoint> getLocationStream({
    required int intervalSeconds,
    required double distanceFilter,
  }) {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: distanceFilter.toInt(),
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings).map(
      (position) => LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
        timestamp: position.timestamp,
      ),
    );
  }
}
