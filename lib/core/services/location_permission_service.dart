import 'package:geolocator/geolocator.dart';

enum LocationAccessStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}

abstract class ILocationPermissionService {
  Future<bool> isLocationServiceEnabled();
  Future<LocationAccessStatus> checkPermission();
  Future<LocationAccessStatus> requestForegroundPermission();
  Future<LocationAccessStatus> requestBackgroundPermission();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class LocationPermissionService implements ILocationPermissionService {
  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 3),
        onTimeout: () => true,
      );
    } catch (_) {
      return true;
    }
  }

  @override
  Future<LocationAccessStatus> checkPermission() async {
    try {
      final permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 10),
        onTimeout: () => LocationPermission.unableToDetermine,
      );
      if (permission == LocationPermission.denied) {
        return LocationAccessStatus.denied;
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationAccessStatus.permanentlyDenied;
      }
      if (permission == LocationPermission.unableToDetermine) {
        return LocationAccessStatus.denied;
      }

      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationAccessStatus.serviceDisabled;
      }

      return _mapPermissionToStatus(permission);
    } catch (_) {
      return LocationAccessStatus.denied;
    }
  }

  @override
  Future<LocationAccessStatus> requestForegroundPermission() async {
    try {
      var permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 10),
        onTimeout: () => LocationPermission.denied,
      );
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 45),
          onTimeout: () => LocationPermission.denied,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationAccessStatus.permanentlyDenied;
      }
      if (permission == LocationPermission.denied) {
        return LocationAccessStatus.denied;
      }

      // Only after user has responded to permission, check if device GPS hardware is enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationAccessStatus.serviceDisabled;
      }

      return _mapPermissionToStatus(permission);
    } catch (_) {
      return LocationAccessStatus.denied;
    }
  }

  @override
  Future<LocationAccessStatus> requestBackgroundPermission() async {
    final currentStatus = await checkPermission();
    if (currentStatus != LocationAccessStatus.granted) {
      final fgStatus = await requestForegroundPermission();
      if (fgStatus != LocationAccessStatus.granted) {
        return fgStatus;
      }
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) {
      return LocationAccessStatus.granted;
    }

    // On Android 10+ and iOS, background permission must be prompted explicitly
    final requested = await Geolocator.requestPermission();
    return _mapPermissionToStatus(requested);
  }

  @override
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  LocationAccessStatus _mapPermissionToStatus(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccessStatus.granted;
      case LocationPermission.denied:
        return LocationAccessStatus.denied;
      case LocationPermission.deniedForever:
      case LocationPermission.unableToDetermine:
        return LocationAccessStatus.permanentlyDenied;
    }
  }
}
