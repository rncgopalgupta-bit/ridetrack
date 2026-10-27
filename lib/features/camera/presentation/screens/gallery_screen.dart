import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ridetrack/features/camera/domain/entities/pod_photo.dart';
import 'package:ridetrack/features/camera/presentation/bloc/camera_bloc.dart';
import 'package:ridetrack/features/camera/presentation/bloc/camera_event.dart';
import 'package:ridetrack/features/camera/presentation/bloc/camera_state.dart';
import 'custom_camera_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CameraBloc>().add(const LoadGalleryEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof-of-Delivery Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CameraBloc>().add(const LoadGalleryEvent());
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.camera_alt),
        label: const Text('Capture POD'),
        onPressed: () async {
          final cameraBloc = context.read<CameraBloc>();
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CustomCameraScreen()),
          );
          cameraBloc.add(const LoadGalleryEvent());
        },
      ),
      body: BlocConsumer<CameraBloc, CameraState>(
        listener: (context, state) {
          if (state is CameraPhotoCaptured) {
            context.read<CameraBloc>().add(const LoadGalleryEvent());
          }
        },
        builder: (context, state) {
          if (state is CameraInitial || state is CameraProcessingPhoto) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CameraError) {
            return Center(
              child: Text(state.message, style: const TextStyle(color: Colors.red)),
            );
          }

          if (state is GalleryLoaded) {
            if (state.photos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 72, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No Delivery Photos Captured Yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap "Capture POD" to take a delivery photo with GPS timestamp overlay.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              cacheExtent: 150.0,
              padding: const EdgeInsets.all(12),
              itemCount: state.photos.length,
              itemBuilder: (context, index) {
                final photo = state.photos[index];
                return _buildPhotoCard(context, photo);
              },
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildPhotoCard(BuildContext context, PodPhoto photo) {
    final sizeKb = (photo.fileSizeBytes / 1024).toStringAsFixed(1);
    final formattedTime = DateFormat('MMM dd, yyyy • HH:mm:ss').format(photo.timestamp);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openFullPhotoViewer(context, photo),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Image.file(
                File(photo.thumbnailPath),
                fit: BoxFit.cover,
                cacheWidth: 300,
                cacheHeight: 300,
                errorBuilder: (ctx, err, stack) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            photo.id.startsWith('delivery_')
                                ? 'STOP: ${photo.id.split('_').length >= 2 ? photo.id.split('_')[1] : photo.id}'
                                : 'POD-${photo.id.substring(0, photo.id.length >= 8 ? 8 : photo.id.length).toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$sizeKb KB',
                            style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(formattedTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 13, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${photo.latitude.toStringAsFixed(4)}, ${photo.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _confirmDelete(context, photo.id),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String photoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Proof of Delivery?'),
        content: const Text('This will remove the photo and its thumbnail permanently.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<CameraBloc>().add(DeletePhotoEvent(photoId));
            },
          ),
        ],
      ),
    );
  }

  void _openFullPhotoViewer(BuildContext context, PodPhoto photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text('POD-${photo.id.substring(0, 8).toUpperCase()}'),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.file(File(photo.fullImagePath)),
            ),
          ),
        ),
      ),
    );
  }
}
