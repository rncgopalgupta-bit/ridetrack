import 'package:equatable/equatable.dart';
import 'sync_status.dart';

class DeliveryRecord extends Equatable {
  final String id;
  final String recipientName;
  final String address;
  final String phone;
  final String status; // 'assigned', 'out_for_delivery', 'completed'
  final String? signaturePath;
  final String? photoProofPath;
  final DateTime? completedAt;
  final SyncStatus syncStatus;
  final int localVersion;
  final int serverVersion;
  final int retryCount;
  final String? syncError;

  const DeliveryRecord({
    required this.id,
    required this.recipientName,
    required this.address,
    required this.phone,
    this.status = 'assigned',
    this.signaturePath,
    this.photoProofPath,
    this.completedAt,
    this.syncStatus = SyncStatus.synced,
    this.localVersion = 1,
    this.serverVersion = 1,
    this.retryCount = 0,
    this.syncError,
  });

  DeliveryRecord copyWith({
    String? id,
    String? recipientName,
    String? address,
    String? phone,
    String? status,
    String? signaturePath,
    String? photoProofPath,
    DateTime? completedAt,
    SyncStatus? syncStatus,
    int? localVersion,
    int? serverVersion,
    int? retryCount,
    String? syncError,
  }) {
    return DeliveryRecord(
      id: id ?? this.id,
      recipientName: recipientName ?? this.recipientName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      signaturePath: signaturePath ?? this.signaturePath,
      photoProofPath: photoProofPath ?? this.photoProofPath,
      completedAt: completedAt ?? this.completedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      localVersion: localVersion ?? this.localVersion,
      serverVersion: serverVersion ?? this.serverVersion,
      retryCount: retryCount ?? this.retryCount,
      syncError: syncError ?? this.syncError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipient_name': recipientName,
      'address': address,
      'phone': phone,
      'status': status,
      'signature_path': signaturePath,
      'photo_proof_path': photoProofPath,
      'completed_at': completedAt?.toIso8601String(),
      'sync_status': syncStatus.toDbValue(),
      'local_version': localVersion,
      'server_version': serverVersion,
      'retry_count': retryCount,
      'sync_error': syncError,
    };
  }

  factory DeliveryRecord.fromMap(Map<String, dynamic> map) {
    return DeliveryRecord(
      id: map['id'] as String,
      recipientName: map['recipient_name'] as String,
      address: map['address'] as String,
      phone: map['phone'] as String,
      status: map['status'] as String? ?? 'assigned',
      signaturePath: map['signature_path'] as String?,
      photoProofPath: map['photo_proof_path'] as String?,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String) : null,
      syncStatus: SyncStatusX.fromDbValue(map['sync_status'] as String? ?? 'pending'),
      localVersion: map['local_version'] as int? ?? 1,
      serverVersion: map['server_version'] as int? ?? 1,
      retryCount: map['retry_count'] as int? ?? 0,
      syncError: map['sync_error'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        recipientName,
        address,
        phone,
        status,
        signaturePath,
        photoProofPath,
        completedAt,
        syncStatus,
        localVersion,
        serverVersion,
        retryCount,
        syncError,
      ];
}
