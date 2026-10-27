import 'dart:async';
import '../../domain/entities/delivery_record.dart';

class SyncRemoteResult {
  final bool isSuccess;
  final bool hasConflict;
  final int newServerVersion;
  final String? errorMessage;
  final DeliveryRecord? conflictingServerRecord;

  const SyncRemoteResult({
    required this.isSuccess,
    this.hasConflict = false,
    required this.newServerVersion,
    this.errorMessage,
    this.conflictingServerRecord,
  });
}

abstract class IDeliveryRemoteDataSource {
  Future<SyncRemoteResult> uploadDeliveryCompletion(DeliveryRecord record);
}

class MockDeliveryRemoteDataSource implements IDeliveryRemoteDataSource {
  // In-memory mock server state to demonstrate conflict resolution
  final Map<String, int> _serverVersions = {
    'DEL-201': 1,
    'DEL-202': 1,
    'DEL-203': 1,
  };

  @override
  Future<SyncRemoteResult> uploadDeliveryCompletion(DeliveryRecord record) async {
    // Simulate real-world network latency (600ms)
    await Future.delayed(const Duration(milliseconds: 600));

    final currentServerVersion = _serverVersions[record.id] ?? 1;

    /*
     * CONFLICT RESOLUTION ARCHITECTURE:
     * If the client's cached serverVersion is strictly less than current serverVersion,
     * another agent or central dispatcher already committed changes to this record.
     * Strategy: Optimistic concurrency control (OCC).
     * If conflicting, the server rejects the overwrite and provides the current authoritative snapshot.
     */
    if (record.serverVersion < currentServerVersion) {
      return SyncRemoteResult(
        isSuccess: false,
        hasConflict: true,
        newServerVersion: currentServerVersion,
        errorMessage: 'Version conflict: Record was updated on server (v$currentServerVersion).',
        conflictingServerRecord: record.copyWith(
          serverVersion: currentServerVersion,
          status: 'reassigned_by_dispatcher',
        ),
      );
    }

    // Happy path: Update succeeds, server advances version
    final updatedVersion = currentServerVersion + 1;
    _serverVersions[record.id] = updatedVersion;

    return SyncRemoteResult(
      isSuccess: true,
      hasConflict: false,
      newServerVersion: updatedVersion,
    );
  }
}
