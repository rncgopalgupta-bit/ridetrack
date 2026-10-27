import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/services/background_tracking_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/camera/presentation/bloc/camera_bloc.dart';
import 'features/camera/presentation/bloc/camera_event.dart';
import 'features/delivery_sync/presentation/bloc/delivery_bloc.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/tracking/presentation/bloc/tracking_bloc.dart';

void main() async {
  // 1. Ensure Flutter engine bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load environment variables with fallback
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // If .env is missing or invalid, default configurations apply
  }

  // 3. Initialize Clean Architecture dependency injection
  await initDependencies();

  // 4. Initialize Foreground task notification config (Android OEM survivability)
  BackgroundTrackingService.initialize();

  // 5. Mount Root App immediately to render first frame in under 1 second
  runApp(const RideTrackApp());

  // 6. DEFERRED COLD START PATTERN: Heavy non-critical service registrations (FCM / Local Notifications)
  // are offloaded after the first visual frame renders so the main UI isolate is never blocked.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.initialize();
  });
}

class RideTrackApp extends StatelessWidget {
  const RideTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TrackingBloc>(
          create: (_) => sl<TrackingBloc>(),
        ),
        BlocProvider<DeliveryBloc>(
          create: (_) => sl<DeliveryBloc>(),
        ),
        BlocProvider<CameraBloc>(
          create: (_) => sl<CameraBloc>()..add(const LoadGalleryEvent()),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: NotificationService.navigatorKey,
        home: const HomeScreen(),
      ),
    );
  }
}
