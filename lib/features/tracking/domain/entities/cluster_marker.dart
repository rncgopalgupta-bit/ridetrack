import 'package:equatable/equatable.dart';

class ClusterMarker extends Equatable {
  final String id;
  final double latitude;
  final double longitude;
  final int count;
  final bool isCluster;
  final String? title;
  final String? snippet;

  const ClusterMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.count,
    required this.isCluster,
    this.title,
    this.snippet,
  });

  @override
  List<Object?> get props => [id, latitude, longitude, count, isCluster, title, snippet];
}
