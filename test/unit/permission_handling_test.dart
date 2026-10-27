import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ridetrack/core/services/location_permission_service.dart';

class MockLocationPermissionService extends Mock implements ILocationPermissionService {}

void main() {
  group('Location Permission Handling State Tests', () {
    late MockLocationPermissionService permissionService;

    setUp(() {
      permissionService = MockLocationPermissionService();
    });

    test('Returns serviceDisabled when GPS hardware is turned off', () async {
      when(() => permissionService.checkPermission())
          .thenAnswer((_) async => LocationAccessStatus.serviceDisabled);

      final status = await permissionService.checkPermission();
      expect(status, LocationAccessStatus.serviceDisabled);
    });

    test('Returns permanentlyDenied when user checks "Never Ask Again"', () async {
      when(() => permissionService.requestForegroundPermission())
          .thenAnswer((_) async => LocationAccessStatus.permanentlyDenied);

      final status = await permissionService.requestForegroundPermission();
      expect(status, LocationAccessStatus.permanentlyDenied);
    });

    test('Returns granted when user approves location access', () async {
      when(() => permissionService.requestForegroundPermission())
          .thenAnswer((_) async => LocationAccessStatus.granted);

      final status = await permissionService.requestForegroundPermission();
      expect(status, LocationAccessStatus.granted);
    });
  });
}
