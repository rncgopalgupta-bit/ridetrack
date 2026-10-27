import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ridetrack/core/services/notification_service.dart';
import 'package:ridetrack/features/camera/presentation/bloc/camera_bloc.dart';
import 'package:ridetrack/features/camera/presentation/bloc/camera_event.dart';
import 'package:ridetrack/features/tracking/presentation/bloc/tracking_bloc.dart';
import 'package:ridetrack/features/tracking/presentation/bloc/tracking_event.dart';
import 'package:ridetrack/features/tracking/presentation/bloc/tracking_state.dart';
import 'package:ridetrack/features/tracking/presentation/screens/tracking_screen.dart';
import 'package:ridetrack/features/delivery_sync/presentation/screens/delivery_list_screen.dart';
import 'package:ridetrack/features/camera/presentation/screens/gallery_screen.dart';
import 'package:ridetrack/features/platform_diagnostics/presentation/screens/diagnostics_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  bool _hasPromptedNotification = false;
  bool _hasDispatchedAlert = false;

  final List<Widget> _screens = const [
    TrackingScreen(),
    DeliveryListScreen(),
    GalleryScreen(),
    DiagnosticsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Step 1: Prompt Location Permission FIRST on launch
      if (context.read<TrackingBloc>().state is TrackingInitial) {
        context.read<TrackingBloc>().add(const InitializeTrackingEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<TrackingBloc, TrackingState>(
        listener: (context, state) async {
          // Step 2: Once Location is resolved (map loaded or permission fallback shown), prompt Notification SECOND
          if ((state is TrackingLoaded || state is TrackingPermissionDenied) && !_hasPromptedNotification) {
            _hasPromptedNotification = true;

            // Wait 1000ms after location dialog dismissed and map rendered
            await Future.delayed(const Duration(milliseconds: 1000));
            if (!context.mounted) return;
            await NotificationService.requestNotificationPermissions();

            // Step 3: Automatically dispatch simulated delivery assignment alert (DEL-201) after 3s
            if (!_hasDispatchedAlert) {
              _hasDispatchedAlert = true;
              await Future.delayed(const Duration(seconds: 3));
              if (!context.mounted) return;

              final del201 = NotificationService.alertsNotifier.value.firstWhere(
                (n) => n.deliveryId == 'DEL-201',
                orElse: () => NotificationAlertItem(deliveryId: '', title: '', body: ''),
              );
              if (!del201.isCompleted) {
                NotificationService.simulateIncomingFcmStopAssignment(
                  context: context,
                  deliveryId: 'DEL-201',
                  title: 'New Delivery Assigned: DEL-201',
                  body: 'Drop-off parcel for Rahul Verma at Connaught Place.',
                );
              }
            }
          }
        },
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 2) {
            context.read<CameraBloc>().add(const LoadGalleryEvent());
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Tracking',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Deliveries',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'POD Gallery',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Diagnostics',
          ),
        ],
      ),
    );
  }
}
