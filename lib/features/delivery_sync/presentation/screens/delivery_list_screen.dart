import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ridetrack/core/services/notification_service.dart';
import 'package:ridetrack/features/delivery_sync/domain/entities/delivery_record.dart';
import 'package:ridetrack/features/delivery_sync/domain/entities/sync_status.dart';
import 'package:ridetrack/features/delivery_sync/presentation/bloc/delivery_bloc.dart';
import 'package:ridetrack/features/delivery_sync/presentation/bloc/delivery_event.dart';
import 'package:ridetrack/features/delivery_sync/presentation/bloc/delivery_state.dart';
import 'delivery_detail_screen.dart';

class DeliveryListScreen extends StatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DeliveryBloc>().add(const LoadDeliveriesEvent());
    final state = context.read<DeliveryBloc>().state;
    if (state is DeliveryLoaded) {
      for (final delivery in state.deliveries) {
        if (delivery.status == 'completed') {
          NotificationService.markAlertAsCompleted(delivery.id);
        }
      }
    }
  }

  void _triggerSimulatedFcmNotification(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ValueListenableBuilder<List<NotificationAlertItem>>(
          valueListenable: NotificationService.alertsNotifier,
          builder: (context, notifications, _) {
            final unreadCount = notifications.where((n) => !n.isRead && !n.isCompleted).length;
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Delivery Notifications',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount pending',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap an assignment notification to view delivery stop details directly.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ...notifications.map((item) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: item.isCompleted
                            ? Colors.green.shade100
                            : (item.isRead
                                ? Colors.grey.shade200
                                : (item.deliveryId == 'DEL-201' ? Colors.blue : Colors.purple)),
                        child: Icon(
                          item.isCompleted
                              ? Icons.check_circle_outline
                              : (item.isRead ? Icons.mark_email_read : Icons.notifications_active),
                          color: item.isCompleted
                              ? Colors.green.shade800
                              : (item.isRead ? Colors.grey.shade600 : Colors.white),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: item.isRead || item.isCompleted ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        item.isCompleted
                            ? 'Stop completed • Tap to view'
                            : (item.isRead ? 'Opened • Tap to view' : item.body),
                        style: TextStyle(
                          fontSize: 12,
                          color: item.isCompleted
                              ? Colors.teal.shade700
                              : (item.isRead ? Colors.grey.shade600 : const Color(0xFF0070BA)),
                          fontWeight: item.isRead || item.isCompleted ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        NotificationService.markAlertAsRead(item.deliveryId);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DeliveryDetailScreen(deliveryId: item.deliveryId),
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Field Deliveries & Sync Queue'),
        ),
        actions: [
          ValueListenableBuilder<List<NotificationAlertItem>>(
            valueListenable: NotificationService.alertsNotifier,
            builder: (context, alerts, child) {
              final unreadCount = alerts.where((n) => !n.isRead && !n.isCompleted).length;
              return IconButton(
                tooltip: 'Delivery Notifications',
                icon: Badge(
                  label: Text('$unreadCount'),
                  isLabelVisible: unreadCount > 0,
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.notifications_active_outlined),
                ),
                onPressed: () => _triggerSimulatedFcmNotification(context),
              );
            },
          ),
          BlocBuilder<DeliveryBloc, DeliveryState>(
            builder: (context, state) {
              final isSyncing = state is DeliveryLoaded && state.isSyncing;
              return IconButton(
                tooltip: 'Trigger Sync Queue',
                icon: isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync),
                onPressed: isSyncing
                    ? null
                    : () {
                        context.read<DeliveryBloc>().add(const TriggerSyncQueueEvent());
                      },
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<DeliveryBloc, DeliveryState>(
        listener: (context, state) {
          if (state is DeliveryLoaded) {
            for (final delivery in state.deliveries) {
              if (delivery.status == 'completed') {
                NotificationService.markAlertAsCompleted(delivery.id);
              }
            }
          }
        },
        builder: (context, state) {
          if (state is DeliveryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DeliveryError) {
            return Center(
              child: Text(state.message, style: const TextStyle(color: Colors.red)),
            );
          }

          if (state is DeliveryLoaded) {
            return Column(
              children: [
                _buildNetworkHeader(state),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      context.read<DeliveryBloc>().add(const LoadDeliveriesEvent());
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.deliveries.length,
                      separatorBuilder: (ctx, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final delivery = state.deliveries[index];
                        return _buildDeliveryCard(context, delivery);
                      },
                    ),
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildNetworkHeader(DeliveryLoaded state) {
    final bool isOnline = state.isConnected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            size: 18,
            color: isOnline ? Colors.green.shade800 : Colors.red.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.lastSyncMessage ?? (isOnline ? 'Online • Auto-sync active' : 'Offline • Disk queue active'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOnline ? Colors.green.shade900 : Colors.red.shade900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.pendingSyncCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${state.pendingSyncCount} Pending',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context, DeliveryRecord delivery) {
    final isCompleted = delivery.status == 'completed';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isCompleted ? Colors.green.shade100 : Colors.blue.shade100,
          child: Icon(
            isCompleted ? Icons.check : Icons.local_shipping,
            color: isCompleted ? Colors.green.shade800 : Colors.blue.shade800,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              delivery.id,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            _buildSyncBadge(delivery.syncStatus),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              delivery.recipientName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
            ),
            Text(
              delivery.address,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeliveryDetailScreen(
                deliveryId: delivery.id,
                initialRecord: delivery,
              ),
            ),
          );
          if (context.mounted) {
            context.read<DeliveryBloc>().add(const LoadDeliveriesEvent());
          }
        },
      ),
    );
  }

  Widget _buildSyncBadge(SyncStatus status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}
