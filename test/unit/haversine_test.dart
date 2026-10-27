import 'package:flutter_test/flutter_test.dart';
import 'package:ridetrack/core/utils/haversine.dart';

void main() {
  group('Haversine Formula Pure Dart Tests', () {
    test('Identical points return zero distance', () {
      final distance = Haversine.calculateDistanceInMeters(
        startLatitude: 28.6139,
        startLongitude: 77.2090,
        endLatitude: 28.6139,
        endLongitude: 77.2090,
      );

      expect(distance, 0.0);
    });

    test('Distance between New York and London is approximately 5570 km', () {
      // New York: 40.7128° N, 74.0060° W
      // London: 51.5074° N, 0.1278° W
      final distanceKm = Haversine.calculateDistanceInKilometers(
        startLatitude: 40.7128,
        startLongitude: -74.0060,
        endLatitude: 51.5074,
        endLongitude: -0.1278,
      );

      // Expected distance is ~5570 km (allow within 0.5% margin of error)
      expect(distanceKm, greaterThan(5550));
      expect(distanceKm, lessThan(5600));
    });

    test('Short range distance between two nearby delivery stops', () {
      // Connaught Place to India Gate (~2.5 km)
      final distanceMeters = Haversine.calculateDistanceInMeters(
        startLatitude: 28.6315,
        startLongitude: 77.2167,
        endLatitude: 28.6129,
        endLongitude: 77.2295,
      );

      expect(distanceMeters, greaterThan(2200));
      expect(distanceMeters, lessThan(2700));
    });
  });
}
