import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/repositories/delivery_repository.dart';
import 'delivery_event.dart';
import 'delivery_state.dart';

class DeliveryBloc extends Bloc<DeliveryEvent, DeliveryState> {
  final IDeliveryRepository deliveryRepository;
  StreamSubscription<bool>? _connectivitySubscription;

  DeliveryBloc({required this.deliveryRepository}) : super(const DeliveryInitial()) {
    on<LoadDeliveriesEvent>(_onLoadDeliveries);
    on<CompleteDeliveryEvent>(_onCompleteDelivery);
    on<TriggerSyncQueueEvent>(_onTriggerSyncQueue);
    on<NetworkStatusChangedEvent>(_onNetworkStatusChanged);

    // Watch network state to trigger automatic background sync upon reconnect
    _connectivitySubscription = deliveryRepository.isConnectedStream.listen((isConnected) {
      add(NetworkStatusChangedEvent(isConnected));
    });
  }

  Future<void> _onLoadDeliveries(LoadDeliveriesEvent event, Emitter<DeliveryState> emit) async {
    emit(const DeliveryLoading());
    try {
      final deliveries = await deliveryRepository.getDeliveries();
      final pendingCount = deliveries.where((d) => d.syncStatus != SyncStatus.synced).length;

      emit(DeliveryLoaded(
        deliveries: deliveries,
        pendingSyncCount: pendingCount,
      ));
    } catch (e) {
      emit(DeliveryError('Failed to load deliveries from local storage: ${e.toString()}'));
    }
  }

  Future<void> _onCompleteDelivery(CompleteDeliveryEvent event, Emitter<DeliveryState> emit) async {
    try {
      await deliveryRepository.completeDeliveryOffline(
        deliveryId: event.deliveryId,
        signaturePath: event.signaturePath,
        photoProofPath: event.photoProofPath,
      );

      // Refresh local database state
      final updatedDeliveries = await deliveryRepository.getDeliveries();
      final pendingCount = updatedDeliveries.where((d) => d.syncStatus != SyncStatus.synced).length;

      final bool currentlyOnline = state is DeliveryLoaded ? (state as DeliveryLoaded).isConnected : true;

      emit(DeliveryLoaded(
        deliveries: updatedDeliveries,
        isConnected: currentlyOnline,
        pendingSyncCount: pendingCount,
        lastSyncMessage: currentlyOnline ? 'Delivery saved locally. Triggering sync...' : 'Saved offline to disk queue.',
      ));

      // If connected to internet, attempt instant sync
      if (currentlyOnline) {
        add(const TriggerSyncQueueEvent());
      }
    } catch (e) {
      emit(DeliveryError('Failed to complete delivery: ${e.toString()}'));
    }
  }

  Future<void> _onTriggerSyncQueue(TriggerSyncQueueEvent event, Emitter<DeliveryState> emit) async {
    if (state is! DeliveryLoaded) return;
    final currentState = state as DeliveryLoaded;

    if (!currentState.isConnected) {
      emit(currentState.copyWith(
        lastSyncMessage: 'Offline: Records safely queued on disk.',
      ));
      return;
    }

    emit(currentState.copyWith(isSyncing: true));

    try {
      final syncedCount = await deliveryRepository.syncPendingDeliveries();
      final freshDeliveries = await deliveryRepository.getDeliveries();
      final remainingPending = freshDeliveries.where((d) => d.syncStatus != SyncStatus.synced).length;

      emit(currentState.copyWith(
        deliveries: freshDeliveries,
        isSyncing: false,
        pendingSyncCount: remainingPending,
        lastSyncMessage: syncedCount > 0
            ? 'Successfully synced $syncedCount record(s) to server.'
            : (remainingPending > 0 ? 'Sync completed with pending issues.' : 'All records up to date.'),
      ));
    } catch (e) {
      final freshDeliveries = await deliveryRepository.getDeliveries();
      emit(currentState.copyWith(
        deliveries: freshDeliveries,
        isSyncing: false,
        lastSyncMessage: 'Sync error: ${e.toString()}',
      ));
    }
  }

  Future<void> _onNetworkStatusChanged(NetworkStatusChangedEvent event, Emitter<DeliveryState> emit) async {
    if (state is! DeliveryLoaded) return;
    final currentState = state as DeliveryLoaded;

    final wasOffline = !currentState.isConnected;
    final isNowOnline = event.isConnected;

    emit(currentState.copyWith(
      isConnected: event.isConnected,
      lastSyncMessage: isNowOnline ? 'Internet restored.' : 'No Internet connection. Operating in offline mode.',
    ));

    // When connection is restored automatically trigger sync without user action
    if (wasOffline && isNowOnline && currentState.pendingSyncCount > 0) {
      add(const TriggerSyncQueueEvent());
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
