import 'package:flutter_test/flutter_test.dart';
import 'package:ridetrack/features/tracking/domain/usecases/cluster_markers_usecase.dart';

void main() {
  group('Marker Clustering Algorithm Tests', () {
    late ClusterMarkersUseCase useCase;

    setUp(() {
      useCase = ClusterMarkersUseCase();
    });

    test('Clusters adjacent items at low zoom levels', () {
      final items = [
        const ClusterDeliveryItem(
          id: 'DEL-1',
          title: 'Stop 1',
          address: 'Main Street 1',
          latitude: 28.6139,
          longitude: 77.2090,
        ),
        const ClusterDeliveryItem(
          id: 'DEL-2',
          title: 'Stop 2',
          address: 'Main Street 2',
          latitude: 28.6140,
          longitude: 77.2091,
        ),
      ];

      final clusters = useCase.execute(items: items, zoomLevel: 10.0);

      expect(clusters.length, 1);
      expect(clusters.first.isCluster, isTrue);
      expect(clusters.first.count, 2);
    });

    test('Separates markers into individual points at high zoom levels (>= 16)', () {
      final items = [
        const ClusterDeliveryItem(
          id: 'DEL-1',
          title: 'Stop 1',
          address: 'Main Street 1',
          latitude: 28.6139,
          longitude: 77.2090,
        ),
        const ClusterDeliveryItem(
          id: 'DEL-2',
          title: 'Stop 2',
          address: 'Main Street 2',
          latitude: 28.6140,
          longitude: 77.2091,
        ),
      ];

      final clusters = useCase.execute(items: items, zoomLevel: 17.0);

      expect(clusters.length, 2);
      expect(clusters.every((c) => !c.isCluster), isTrue);
      expect(clusters.every((c) => c.count == 1), isTrue);
    });
  });
}
