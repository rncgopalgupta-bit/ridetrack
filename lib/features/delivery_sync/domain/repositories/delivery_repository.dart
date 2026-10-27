import '../entities/delivery_record.dart';

abstract class IDeliveryRepository {
  Future<List<DeliveryRecord>> getDeliveries();
  Future<DeliveryRecord?> getDeliveryById(String id);
  Future<void> completeDeliveryOffline({
    required String deliveryId,
    required String signaturePath,
    String? photoProofPath,
  });
  Future<int> syncPendingDeliveries();
  Stream<bool> get isConnectedStream;
}
