import 'dart:math' as math;
import '../entities/cluster_marker.dart';

class ClusterDeliveryItem {
  final String id;
  final String title;
  final String address;
  final double latitude;
  final double longitude;

  const ClusterDeliveryItem({
    required this.id,
    required this.title,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class ClusterMarkersUseCase {
  List<ClusterMarker> execute({
    required List<ClusterDeliveryItem> items,
    required double zoomLevel,
  }) {
    if (items.isEmpty) return const [];

    // When zoomed in close (zoom >= 16), keep markers individual
    if (zoomLevel >= 16.0) {
      return items.map((item) {
        return ClusterMarker(
          id: item.id,
          latitude: item.latitude,
          longitude: item.longitude,
          count: 1,
          isCluster: false,
          title: item.title,
          snippet: item.address,
        );
      }).toList();
    }

    // Grid-based spatial partitioning
    final double gridSize = 360.0 / (math.pow(2, zoomLevel.clamp(3.0, 15.0)) * 4.0);
    final Map<String, List<ClusterDeliveryItem>> buckets = {};

    for (final item in items) {
      final int cellX = (item.longitude / gridSize).floor();
      final int cellY = (item.latitude / gridSize).floor();
      final String cellKey = '$cellX:$cellY';

      buckets.putIfAbsent(cellKey, () => []).add(item);
    }

    final List<ClusterMarker> clusters = [];

    buckets.forEach((cellKey, cellItems) {
      if (cellItems.length == 1) {
        final single = cellItems.first;
        clusters.add(
          ClusterMarker(
            id: single.id,
            latitude: single.latitude,
            longitude: single.longitude,
            count: 1,
            isCluster: false,
            title: single.title,
            snippet: single.address,
          ),
        );
      } else {
        // Compute cluster centroid
        double sumLat = 0;
        double sumLng = 0;
        for (final item in cellItems) {
          sumLat += item.latitude;
          sumLng += item.longitude;
        }

        final double avgLat = sumLat / cellItems.length;
        final double avgLng = sumLng / cellItems.length;

        clusters.add(
          ClusterMarker(
            id: 'cluster_$cellKey',
            latitude: avgLat,
            longitude: avgLng,
            count: cellItems.length,
            isCluster: true,
            title: '${cellItems.length} Deliveries in Zone',
            snippet: 'Zoom in to inspect individual delivery stops',
          ),
        );
      }
    });

    return clusters;
  }
}
