import 'package:equatable/equatable.dart';
import '../../domain/entities/delivery_record.dart';

abstract class DeliveryState extends Equatable {
  const DeliveryState();

  @override
  List<Object?> get props => [];
}

class DeliveryInitial extends DeliveryState {
  const DeliveryInitial();
}

class DeliveryLoading extends DeliveryState {
  const DeliveryLoading();
}

class DeliveryLoaded extends DeliveryState {
  final List<DeliveryRecord> deliveries;
  final bool isConnected;
  final bool isSyncing;
  final int pendingSyncCount;
  final String? lastSyncMessage;

  const DeliveryLoaded({
    required this.deliveries,
    this.isConnected = true,
    this.isSyncing = false,
    this.pendingSyncCount = 0,
    this.lastSyncMessage,
  });

  DeliveryLoaded copyWith({
    List<DeliveryRecord>? deliveries,
    bool? isConnected,
    bool? isSyncing,
    int? pendingSyncCount,
    String? lastSyncMessage,
  }) {
    return DeliveryLoaded(
      deliveries: deliveries ?? this.deliveries,
      isConnected: isConnected ?? this.isConnected,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      lastSyncMessage: lastSyncMessage,
    );
  }

  @override
  List<Object?> get props => [
        deliveries,
        isConnected,
        isSyncing,
        pendingSyncCount,
        lastSyncMessage,
      ];
}

class DeliveryError extends DeliveryState {
  final String message;

  const DeliveryError(this.message);

  @override
  List<Object?> get props => [message];
}
