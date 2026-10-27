import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/delivery_sync/presentation/screens/delivery_detail_screen.dart';

class NotificationAlertItem {
  final String deliveryId;
  final String title;
  final String body;
  bool isDelivered;
  bool isRead;
  bool isCompleted;

  NotificationAlertItem({
    required this.deliveryId,
    required this.title,
    required this.body,
    this.isDelivered = false,
    this.isRead = false,
    this.isCompleted = false,
  });
}

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static final ValueNotifier<List<NotificationAlertItem>> alertsNotifier = ValueNotifier([
    NotificationAlertItem(
      deliveryId: 'DEL-201',
      title: 'New Delivery Assigned: DEL-201',
      body: 'Drop-off parcel for Rahul Verma at Connaught Place.',
    ),
    NotificationAlertItem(
      deliveryId: 'DEL-202',
      title: 'New Delivery Assigned: DEL-202',
      body: 'Drop-off parcel for Sneha Patel at KG Marg.',
    ),
  ]);

  static int get unreadAlertCount => alertsNotifier.value.where((n) => !n.isRead && !n.isCompleted).length;

  static void markAlertAsDelivered(String deliveryId) {
    for (final item in alertsNotifier.value) {
      if (item.deliveryId == deliveryId) {
        item.isDelivered = true;
      }
    }
    alertsNotifier.value = List.from(alertsNotifier.value);
  }

  static void markAlertAsRead(String deliveryId) {
    for (final item in alertsNotifier.value) {
      if (item.deliveryId == deliveryId) {
        item.isDelivered = true;
        item.isRead = true;
      }
    }
    alertsNotifier.value = List.from(alertsNotifier.value);
  }

  static void markAlertAsCompleted(String deliveryId) {
    for (final item in alertsNotifier.value) {
      if (item.deliveryId == deliveryId) {
        item.isDelivered = true;
        item.isRead = true;
        item.isCompleted = true;
      }
    }
    alertsNotifier.value = List.from(alertsNotifier.value);
  }

  static void resetAllAlerts() {
    for (final item in alertsNotifier.value) {
      item.isDelivered = false;
      item.isRead = false;
      item.isCompleted = false;
    }
    alertsNotifier.value = List.from(alertsNotifier.value);
  }

  /// Explicitly requests Android 13+ (API 33+) notification runtime permission.
  /// Call sequentially after location permission is granted to prevent Android dialog deadlock.
  static Future<bool> requestNotificationPermissions() async {
    try {
      final granted = await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'ridetrack_fcm_assignments',
    'Delivery Stop Assignments',
    description: 'Real-time assignment alerts for field agents',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          _handleDeepLinkNavigation(response.payload!);
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _requestIosPermissions();

    try {
      if (Firebase.apps.isNotEmpty) {
        _registerFcmHandlers();
      }
    } catch (_) {}
  }

  static Future<void> _requestIosPermissions() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: true,
        sound: true,
      );

      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
        case AuthorizationStatus.denied:
        case AuthorizationStatus.notDetermined:
        default:
          break;
      }
    } catch (_) {}
  }

  static void _registerFcmHandlers() {
    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final data = message.data;
      final deliveryId = data['delivery_id'] ?? 'DEL-201';

      if (notification != null) {
        markAlertAsDelivered(deliveryId);
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title ?? 'New Delivery Assignment',
          body: notification.body ?? 'Tap to view assignment details.',
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: deliveryId,
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final deliveryId = message.data['delivery_id'];
      if (deliveryId != null) {
        _handleDeepLinkNavigation(deliveryId);
      }
    });

    messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        final deliveryId = message.data['delivery_id'];
        if (deliveryId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleDeepLinkNavigation(deliveryId);
          });
        }
      }
    });
  }

  static void _handleDeepLinkNavigation(String deliveryId) {
    markAlertAsRead(deliveryId);
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => DeliveryDetailScreen(deliveryId: deliveryId),
      ),
    );
  }

  static Future<void> simulateIncomingFcmStopAssignment({
    BuildContext? context,
    required String deliveryId,
    required String title,
    required String body,
  }) async {
    markAlertAsDelivered(deliveryId);

    // 1. Request Android 13+ notification runtime permission if not granted yet
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}

    // 2. Trigger real system notification in the Android notification drawer / status bar
    try {
      await _localNotifications.cancel(id: deliveryId.hashCode);
      await _localNotifications.show(
        id: deliveryId.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: deliveryId,
      );
    } catch (_) {}

    // 3. Show in-app foreground banner with OPEN STOP deep-link action (fixed right overflow)
    final activeContext = navigatorKey.currentContext ?? context;
    if (activeContext != null && activeContext.mounted) {
      ScaffoldMessenger.of(activeContext).hideCurrentSnackBar();
      ScaffoldMessenger.of(activeContext).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFF0070BA),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'OPEN STOP',
            textColor: Colors.amberAccent,
            onPressed: () {
              _handleDeepLinkNavigation(deliveryId);
            },
          ),
        ),
      );
    }
  }
}
