import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/entities/delivery_record.dart';
import '../../domain/entities/sync_status.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../datasources/delivery_local_datasource.dart';
import '../datasources/delivery_remote_datasource.dart';

class DeliveryRepositoryImpl implements IDeliveryRepository {
  final IDeliveryLocalDataSource localDataSource;
  final IDeliveryRemoteDataSource remoteDataSource;
  final Connectivity connectivity;

  DeliveryRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.connectivity,
  });

  @override
  Stream<bool> get isConnectedStream {
    return connectivity.onConnectivityChanged.map((results) {
      if (results.isEmpty) return false;
      return results.any((r) => r != ConnectivityResult.none);
    });
  }

  @override
  Future<List<DeliveryRecord>> getDeliveries() {
    return localDataSource.getAllDeliveries();
  }

  @override
  Future<DeliveryRecord?> getDeliveryById(String id) {
    return localDataSource.getDeliveryById(id);
  }

  @override
  Future<void> completeDeliveryOffline({
    required String deliveryId,
    required String signaturePath,
    String? photoProofPath,
  }) async {
    final existing = await localDataSource.getDeliveryById(deliveryId);
    if (existing == null) {
      throw Exception('Delivery with ID $deliveryId not found.');
    }

    final updated = existing.copyWith(
      status: 'completed',
      signaturePath: signaturePath,
      photoProofPath: photoProofPath,
      completedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
      localVersion: existing.localVersion + 1,
    );

    // Persist to local SQLite disk immediately so it survives app crashes or process kills
    await localDataSource.saveDelivery(updated);
  }

  @override
  Future<int> syncPendingDeliveries() async {
    final unsynced = await localDataSource.getUnsyncedDeliveries();
    if (unsynced.isEmpty) return 0;

    int syncedCount = 0;

    for (final item in unsynced) {
      // Mark as syncing in SQLite
      await localDataSource.updateDeliverySyncStatus(item.id, SyncStatus.syncing);

      try {
        final result = await remoteDataSource.uploadDeliveryCompletion(item);

        if (result.isSuccess) {
          await localDataSource.updateDeliverySyncStatus(
            item.id,
            SyncStatus.synced,
            newServerVersion: result.newServerVersion,
          );
          syncedCount++;
        } else if (result.hasConflict) {
          // Handle server conflict: persist error state without losing agent's signature
          await localDataSource.updateDeliverySyncStatus(
            item.id,
            SyncStatus.failed,
            error: result.errorMessage,
          );
        } else {
          await localDataSource.updateDeliverySyncStatus(
            item.id,
            SyncStatus.failed,
            error: result.errorMessage ?? 'Network upload error',
          );
        }
      } catch (e) {
        await localDataSource.updateDeliverySyncStatus(
          item.id,
          SyncStatus.failed,
          error: e.toString(),
        );
      }
    }

    return syncedCount;
  }
}
