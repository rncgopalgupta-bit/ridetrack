class AppConstants {
  static const String appName = 'RideTrack';
  static const String appVersion = '1.0.0';

  // Tracking intervals in seconds
  static const int foregroundTrackingInterval = 15;
  static const int backgroundTrackingInterval = 30;
  static const double minDistanceFilterMeters = 5.0;

  // Background Notification Details
  static const String foregroundServiceNotificationChannelId = 'ridetrack_location_channel';
  static const String foregroundServiceNotificationChannelName = 'RideTrack Agent Tracking';
  static const int foregroundServiceNotificationId = 8821;

  // Database
  static const String databaseName = 'ridetrack_local.db';
  static const int databaseVersion = 1;
  static const String deliveryTableName = 'delivery_sync_queue';

  // Client Webview URL
  static const String clientPortalUrl = 'https://flutter.dev';
}
