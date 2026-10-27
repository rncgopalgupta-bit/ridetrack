import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:ridetrack/core/di/injection_container.dart';
import 'package:ridetrack/core/services/notification_service.dart';
import 'package:ridetrack/features/camera/domain/entities/pod_photo.dart';
import 'package:ridetrack/features/camera/presentation/screens/custom_camera_screen.dart';
import 'package:ridetrack/features/delivery_sync/data/datasources/delivery_local_datasource.dart';
import 'package:ridetrack/features/delivery_sync/domain/entities/delivery_record.dart';
import 'package:ridetrack/features/delivery_sync/domain/entities/sync_status.dart';
import 'package:ridetrack/features/delivery_sync/presentation/bloc/delivery_bloc.dart';
import 'package:ridetrack/features/delivery_sync/presentation/bloc/delivery_event.dart';
import 'package:ridetrack/features/delivery_sync/presentation/widgets/signature_pad_dialog.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final String deliveryId;
  final DeliveryRecord? initialRecord;

  const DeliveryDetailScreen({
    super.key,
    required this.deliveryId,
    this.initialRecord,
  });

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  DeliveryRecord? _delivery;
  String? _capturedSignaturePath;
  String? _capturedPhotoPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _delivery = widget.initialRecord;
    _capturedSignaturePath = widget.initialRecord?.signaturePath;
    _capturedPhotoPath = widget.initialRecord?.photoProofPath;

    if (_delivery == null) {
      _loadDeliveryRecord();
    }
  }

  Future<void> _loadDeliveryRecord() async {
    setState(() => _isLoading = true);
    final localDs = sl<IDeliveryLocalDataSource>();
    final record = await localDs.getDeliveryById(widget.deliveryId);
    if (mounted) {
      if (record?.status == 'completed') {
        NotificationService.markAlertAsCompleted(widget.deliveryId);
      }
      setState(() {
        _delivery = record;
        _capturedSignaturePath = record?.signaturePath;
        _capturedPhotoPath = record?.photoProofPath;
        _isLoading = false;
      });
    }
  }

  Future<void> _openCamera() async {
    final result = await Navigator.of(context).push<PodPhoto>(
      MaterialPageRoute(builder: (_) => CustomCameraScreen(deliveryId: widget.deliveryId)),
    );

    if (result != null && mounted) {
      if (_capturedPhotoPath != null && _capturedPhotoPath != result.fullImagePath) {
        try {
          final oldFile = File(_capturedPhotoPath!);
          if (oldFile.existsSync()) oldFile.deleteSync();
          final oldThumb = File(p.join(
            p.dirname(_capturedPhotoPath!),
            'thumb_${p.basename(_capturedPhotoPath!)}',
          ));
          if (oldThumb.existsSync()) oldThumb.deleteSync();
        } catch (_) {}
      }

      setState(() {
        _capturedPhotoPath = result.fullImagePath;
      });
    }
  }

  Future<void> _openSignaturePad() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SignaturePadDialog(deliveryId: widget.deliveryId),
    );

    if (result != null && mounted) {
      setState(() {
        _capturedSignaturePath = result;
      });
    }
  }

  void _submitCompletion() {
    if (_capturedSignaturePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture customer signature before completing.')),
      );
      return;
    }

    NotificationService.markAlertAsCompleted(widget.deliveryId);

    context.read<DeliveryBloc>().add(
          CompleteDeliveryEvent(
            deliveryId: widget.deliveryId,
            signaturePath: _capturedSignaturePath!,
            photoProofPath: _capturedPhotoPath,
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery marked as completed and queued for sync.'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Stop ${widget.deliveryId}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Not Found')),
        body: Center(
          child: Text('No delivery found for ID: ${widget.deliveryId}'),
        ),
      );
    }

    final d = _delivery!;
    final isAlreadyCompleted = d.status == 'completed';

    return Scaffold(
      appBar: AppBar(
        title: Text('${d.id} • ${d.recipientName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: _buildSyncStatusBadge(d.syncStatus),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          d.recipientName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAlreadyCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            d.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isAlreadyCompleted ? Colors.green.shade800 : Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(child: Text(d.address, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(d.phone, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Local v${d.localVersion} • Server v${d.serverVersion}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        if (d.syncError != null)
                          Flexible(
                            child: Text(
                              d.syncError!,
                              style: const TextStyle(fontSize: 11, color: Colors.red),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Proof of Delivery Verification',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: isAlreadyCompleted ? null : _openCamera,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _capturedPhotoPath != null && File(_capturedPhotoPath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(File(_capturedPhotoPath!), fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Photo Added',
                                          style: TextStyle(color: Colors.white, fontSize: 9)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, color: Theme.of(context).primaryColor, size: 32),
                                const SizedBox(height: 6),
                                const Text('Add POD Photo',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const Text('(Optional GPS stamp)',
                                    style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: isAlreadyCompleted ? null : _openSignaturePad,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _capturedSignaturePath != null && File(_capturedSignaturePath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(File(_capturedSignaturePath!), fit: BoxFit.contain),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Signed',
                                          style: TextStyle(color: Colors.white, fontSize: 9)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.draw, color: Theme.of(context).primaryColor, size: 32),
                                const SizedBox(height: 6),
                                const Text('Capture Signature',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const Text('(Required)',
                                    style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!isAlreadyCompleted)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF0070BA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Complete Delivery Stop', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                onPressed: _submitCompletion,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: Colors.green),
                    SizedBox(width: 8),
                    Text('This delivery stop is completed.',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusBadge(SyncStatus status) {
    Color bg = Colors.grey.shade200;
    Color fg = Colors.grey.shade800;

    switch (status) {
      case SyncStatus.pending:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case SyncStatus.syncing:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case SyncStatus.synced:
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case SyncStatus.failed:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}
