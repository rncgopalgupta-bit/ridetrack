import 'package:equatable/equatable.dart';

abstract class DeliveryEvent extends Equatable {
  const DeliveryEvent();

  @override
  List<Object?> get props => [];
}

class LoadDeliveriesEvent extends DeliveryEvent {
  const LoadDeliveriesEvent();
}

class CompleteDeliveryEvent extends DeliveryEvent {
  final String deliveryId;
  final String signaturePath;
  final String? photoProofPath;

  const CompleteDeliveryEvent({
    required this.deliveryId,
    required this.signaturePath,
    this.photoProofPath,
  });

  @override
  List<Object?> get props => [deliveryId, signaturePath, photoProofPath];
}

class TriggerSyncQueueEvent extends DeliveryEvent {
  const TriggerSyncQueueEvent();
}

class NetworkStatusChangedEvent extends DeliveryEvent {
  final bool isConnected;

  const NetworkStatusChangedEvent(this.isConnected);

  @override
  List<Object?> get props => [isConnected];
}
