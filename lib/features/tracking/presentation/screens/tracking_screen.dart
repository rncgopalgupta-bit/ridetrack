import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../bloc/tracking_bloc.dart';
import '../bloc/tracking_event.dart';
import '../bloc/tracking_state.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  GoogleMapController? _mapController;
  late AnimationController _markerAnimationController;

  LatLng? _previousAgentPosition;
  LatLng? _targetAgentPosition;
  LatLng? _interpolatedAgentPosition;

  BitmapDescriptor? _agentMarkerIcon;
  BitmapDescriptor? _clusterMarkerIcon;
  BitmapDescriptor? _singleStopIcon;

  final ValueNotifier<Set<Marker>> _markersNotifier = ValueNotifier<Set<Marker>>({});
  final ValueNotifier<Set<Polyline>> _polylinesNotifier = ValueNotifier<Set<Polyline>>({});

  bool _isFollowingAgent = true;
  double _lastClusteredZoom = 15.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCustomMarkerIcons();

    _markerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(_onMarkerAnimationFrame);
  }

  DateTime? _lastResumeCheck;

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastResumeCheck != null && now.difference(_lastResumeCheck!).inMilliseconds < 1200) {
        return;
      }
      _lastResumeCheck = now;

      final state = context.read<TrackingBloc>().state;
      if (state is TrackingPermissionDenied ||
          (state is TrackingLoaded && state.currentLocation == null)) {
        context.read<TrackingBloc>().add(const RecheckPermissionEvent());
      }
    }
  }

  Future<void> _initCustomMarkerIcons() async {
    _agentMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    _clusterMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    _singleStopIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  void _onMarkerAnimationFrame() {
    if (_previousAgentPosition == null || _targetAgentPosition == null) return;

    final double t = CurvedAnimation(
      parent: _markerAnimationController,
      curve: Curves.easeInOutCubic,
    ).value;

    final double lat = _previousAgentPosition!.latitude +
        (_targetAgentPosition!.latitude - _previousAgentPosition!.latitude) * t;
    final double lng = _previousAgentPosition!.longitude +
        (_targetAgentPosition!.longitude - _previousAgentPosition!.longitude) * t;

    _interpolatedAgentPosition = LatLng(lat, lng);
    _rebuildMarkerSet();
  }

  void _onLocationChanged(LatLng newPos) {
    if (!mounted) return;
    final bool isFirstFix = _targetAgentPosition == null;
    _previousAgentPosition = _interpolatedAgentPosition ?? _targetAgentPosition ?? newPos;
    _targetAgentPosition = newPos;
    _interpolatedAgentPosition ??= newPos;
    _rebuildMarkerSet();

    if (_mapController == null) return;

    try {
      _markerAnimationController.forward(from: 0.0);
      if (isFirstFix) {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newPos, zoom: 15.5),
          ),
        ).catchError((_) {});
      } else if (_isFollowingAgent) {
        // Follow agent smoothly while preserving the user's manual zoom level
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(newPos),
        ).catchError((_) {});
      }
    } catch (_) {
      _mapController = null;
    }
  }

  void _rebuildMarkerSet() {
    final state = context.read<TrackingBloc>().state;
    final Set<Marker> markers = {};

    if (_interpolatedAgentPosition != null && state is TrackingLoaded && state.currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('agent_live_pin'),
          position: _interpolatedAgentPosition!,
          icon: _agentMarkerIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          infoWindow: const InfoWindow(
            title: 'Agent Live Position',
            snippet: 'Transmitting every 15s',
          ),
        ),
      );
    }

    if (state is TrackingLoaded) {
      for (final cluster in state.clusterMarkers) {
        markers.add(
          Marker(
            markerId: MarkerId(cluster.id),
            position: LatLng(cluster.latitude, cluster.longitude),
            icon: cluster.isCluster
                ? (_clusterMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet))
                : (_singleStopIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)),
            infoWindow: InfoWindow(
              title: cluster.title,
              snippet: cluster.snippet,
            ),
          ),
        );
      }

      if (state.locationHistory.length > 1) {
        final points = state.locationHistory
            .map((pt) => LatLng(pt.latitude, pt.longitude))
            .toList();

        _polylinesNotifier.value = {
          Polyline(
            polylineId: const PolylineId('tracking_breadcrumbs'),
            points: points,
            color: const Color(0xFF0070BA),
            width: 4,
            geodesic: true,
          ),
        };
      }
    }

    _markersNotifier.value = markers;
  }

  void _showApiKeyInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Google Maps API Key Setup'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Why is the map background beige?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'By assessment requirements, this project uses placeholder API keys (.env.example). The Google Maps Android SDK requires a registered Google Cloud API Key with "Maps SDK for Android" enabled to download real vector road tiles.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'How to load live map tiles:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                '1. Open Google Cloud Console -> APIs -> Enable "Maps SDK for Android".\n'
                '2. Generate an API Key.\n'
                '3. Paste it in android/app/src/main/AndroidManifest.xml and .env.\n'
                '4. Re-run flutter run.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            child: const Text('Got It'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _markerAnimationController.dispose();
    _markersNotifier.dispose();
    _polylinesNotifier.dispose();
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Agent Tracking'),
        actions: [
          IconButton(
            tooltip: 'API Key Guide',
            icon: const Icon(Icons.info_outline),
            onPressed: _showApiKeyInfoDialog,
          ),
          BlocBuilder<TrackingBloc, TrackingState>(
            builder: (context, state) {
              if (state is! TrackingLoaded) return const SizedBox.shrink();
              final isBg = state.isBackgroundTrackingActive;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  tooltip: isBg ? 'Background Tracking Active' : 'Start Background Tracking',
                  icon: Icon(
                    isBg ? Icons.battery_saver : Icons.battery_charging_full,
                    color: isBg ? Colors.greenAccent : Colors.white70,
                  ),
                  onPressed: () {
                    context.read<TrackingBloc>().add(const ToggleBackgroundTrackingEvent());
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<TrackingBloc, TrackingState>(
        listener: (context, state) {
          if (state is! TrackingLoaded) {
            _mapController = null;
          }
          if (state is TrackingLoaded && state.currentLocation != null) {
            final newPos = LatLng(
              state.currentLocation!.latitude,
              state.currentLocation!.longitude,
            );
            final bool hasLocationChanged = _targetAgentPosition == null ||
                (_targetAgentPosition!.latitude - newPos.latitude).abs() > 0.00001 ||
                (_targetAgentPosition!.longitude - newPos.longitude).abs() > 0.00001;

            if (hasLocationChanged) {
              _onLocationChanged(newPos);
            }
          }
        },
        builder: (context, state) {
          if (state is TrackingPermissionDenied && _targetAgentPosition == null) {
            _mapController = null;
            return _buildPermissionFallback(context, state);
          }

          final LatLng initialMapCenter = state is TrackingLoaded && state.currentLocation != null
              ? LatLng(state.currentLocation!.latitude, state.currentLocation!.longitude)
              : (_targetAgentPosition ?? const LatLng(28.6139, 77.2090));

          return Stack(
            children: [
              ValueListenableBuilder<Set<Marker>>(
                valueListenable: _markersNotifier,
                builder: (context, markers, _) {
                  return ValueListenableBuilder<Set<Polyline>>(
                    valueListenable: _polylinesNotifier,
                    builder: (context, polylines, _) {
                      return GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initialMapCenter,
                          zoom: 15.0,
                        ),
                        markers: markers,
                        polylines: polylines,
                        myLocationEnabled: state is TrackingLoaded,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        compassEnabled: true,
                        mapToolbarEnabled: false,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          if (_targetAgentPosition != null) {
                            try {
                              _mapController?.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(target: _targetAgentPosition!, zoom: 15.5),
                                ),
                              ).catchError((_) {});
                            } catch (_) {}
                          }
                          _rebuildMarkerSet();
                        },
                        onCameraMoveStarted: () {
                          if (_isFollowingAgent) {
                            setState(() => _isFollowingAgent = false);
                          }
                        },
                        onCameraMove: (position) {
                          _lastClusteredZoom = position.zoom;
                        },
                        onCameraIdle: () {
                          final currentState = context.read<TrackingBloc>().state;
                          if (currentState is TrackingLoaded &&
                              (currentState.currentZoom - _lastClusteredZoom).abs() >= 0.5) {
                            context.read<TrackingBloc>().add(UpdateMapZoomEvent(_lastClusteredZoom));
                          }
                        },
                      );
                    },
                  );
                },
              ),
              if (state is TrackingLoading)
                Container(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.amber),
                        SizedBox(height: 16),
                        Text(
                          'Acquiring GPS Signal...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (state is TrackingLoaded)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: state.gpsWarning != null
                      ? _buildGpsWarningBanner(state)
                      : _buildTrackingMetricsOverlay(state),
                ),
              Positioned(
                bottom: 30,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'recenter_map',
                      elevation: 4,
                      backgroundColor: Colors.white,
                      foregroundColor: _isFollowingAgent ? Theme.of(context).primaryColor : Colors.grey.shade600,
                      tooltip: _isFollowingAgent ? 'Tracking Agent Live' : 'Recenter on Agent',
                      onPressed: () {
                        if (_targetAgentPosition != null) {
                          setState(() => _isFollowingAgent = true);
                          try {
                            _mapController?.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(target: _targetAgentPosition!, zoom: 16.0),
                              ),
                            ).catchError((_) {});
                          } catch (_) {}
                        }
                      },
                      child: Icon(_isFollowingAgent ? Icons.my_location : Icons.location_searching),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      elevation: 4,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, size: 22),
                            tooltip: 'Zoom In',
                            onPressed: () {
                              try {
                                _mapController?.animateCamera(CameraUpdate.zoomIn()).catchError((_) {});
                              } catch (_) {}
                            },
                          ),
                          Container(
                            height: 1,
                            width: 32,
                            color: Colors.grey.shade300,
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove, size: 22),
                            tooltip: 'Zoom Out',
                            onPressed: () {
                              try {
                                _mapController?.animateCamera(CameraUpdate.zoomOut()).catchError((_) {});
                              } catch (_) {}
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGpsWarningBanner(TrackingLoaded state) {
    return Card(
      elevation: 6,
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.amber, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              state.isGpsDisabled ? Icons.location_disabled : Icons.location_off,
              color: Colors.amber,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.isGpsDisabled ? 'GPS Service Disabled' : 'Location Permission Denied',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.gpsWarning ?? 'Turn on GPS for live tracking',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                if (state.isGpsDisabled) {
                  context.read<TrackingBloc>().add(const OpenLocationSettingsEvent());
                } else {
                  context.read<TrackingBloc>().add(const OpenAppSettingsEvent());
                }
              },
              child: Text(
                state.isGpsDisabled ? 'Turn On' : 'Settings',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingMetricsOverlay(TrackingLoaded state) {
    final distanceKm = state.totalDistanceMeters / 1000.0;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMetricItem(
              icon: Icons.route,
              label: 'Distance',
              value: '${distanceKm.toStringAsFixed(2)} km',
            ),
            _buildVerticalDivider(),
            _buildMetricItem(
              icon: Icons.timer,
              label: 'Interval',
              value: state.isBackgroundTrackingActive ? '30s (BG)' : '15s (FG)',
            ),
            _buildVerticalDivider(),
            _buildMetricItem(
              icon: Icons.pin_drop,
              label: 'Zones',
              value: '${state.clusterMarkers.length} Active',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withValues(alpha: 0.3),
    );
  }

  Widget _buildPermissionFallback(BuildContext context, TrackingPermissionDenied state) {
    final bool isGpsDisabled = state.message.contains('Location service') || state.message.contains('GPS');
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isGpsDisabled ? Icons.location_disabled : Icons.location_off,
              size: 64,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            const Text(
              'Location Access Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (isGpsDisabled)
              ElevatedButton.icon(
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Turn On GPS'),
                onPressed: () {
                  context.read<TrackingBloc>().add(const OpenLocationSettingsEvent());
                },
              )
            else if (state.isPermanentlyDenied)
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
                onPressed: () {
                  context.read<TrackingBloc>().add(const OpenAppSettingsEvent());
                },
              )
            else ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text('Grant Location Permission'),
                onPressed: () {
                  context.read<TrackingBloc>().add(const RequestLocationPermissionEvent());
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
                onPressed: () {
                  context.read<TrackingBloc>().add(const OpenAppSettingsEvent());
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
