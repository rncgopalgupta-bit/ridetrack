import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import '../services/location_permission_service.dart';
import '../../features/tracking/data/datasources/location_datasource.dart';
import '../../features/tracking/data/repositories/tracking_repository_impl.dart';
import '../../features/tracking/domain/repositories/tracking_repository.dart';
import '../../features/tracking/domain/usecases/cluster_markers_usecase.dart';
import '../../features/tracking/presentation/bloc/tracking_bloc.dart';

import '../../features/camera/domain/usecases/process_pod_image.dart';
import '../../features/camera/presentation/bloc/camera_bloc.dart';

import '../../features/delivery_sync/data/datasources/delivery_local_datasource.dart';
import '../../features/delivery_sync/data/datasources/delivery_remote_datasource.dart';
import '../../features/delivery_sync/data/repositories/delivery_repository_impl.dart';
import '../../features/delivery_sync/domain/repositories/delivery_repository.dart';
import '../../features/delivery_sync/presentation/bloc/delivery_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Core Services
  sl.registerLazySingleton<ILocationPermissionService>(() => LocationPermissionService());
  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // Module 1: Tracking & Maps
  sl.registerLazySingleton<ILocationDataSource>(() => LocationDataSource());
  sl.registerLazySingleton<ITrackingRepository>(
    () => TrackingRepositoryImpl(locationDataSource: sl()),
  );
  sl.registerLazySingleton(() => ClusterMarkersUseCase());
  sl.registerFactory(
    () => TrackingBloc(
      trackingRepository: sl(),
      permissionService: sl(),
      clusterUseCase: sl(),
    ),
  );

  // Module 2: Camera & Media
  sl.registerLazySingleton(() => ProcessPodImageUseCase());
  sl.registerFactory(
    () => CameraBloc(
      processImageUseCase: sl(),
      deliveryLocalDataSource: sl(),
    ),
  );

  // Module 3: Offline Delivery Sync
  final localDataSource = DeliveryLocalDataSource();
  await localDataSource.initialize();
  sl.registerLazySingleton<IDeliveryLocalDataSource>(() => localDataSource);
  sl.registerLazySingleton<IDeliveryRemoteDataSource>(() => MockDeliveryRemoteDataSource());
  sl.registerLazySingleton<IDeliveryRepository>(
    () => DeliveryRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      connectivity: sl(),
    ),
  );
  sl.registerFactory(() => DeliveryBloc(deliveryRepository: sl()));
}
