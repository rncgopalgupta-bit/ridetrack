import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ridetrack/features/delivery_sync/domain/entities/delivery_record.dart';
import 'package:ridetrack/features/delivery_sync/domain/entities/sync_status.dart';
import 'package:ridetrack/features/delivery_sync/domain/repositories/delivery_repository.dart';
import 'package:ridetrack/features/delivery_sync/presentation/bloc/delivery_bloc.dart';
import 'package:ridetrack/features/delivery_sync/presentation/bloc/delivery_event.dart';
import 'package:ridetrack/features/delivery_sync/presentation/bloc/delivery_state.dart';

class MockDeliveryRepository extends Mock implements IDeliveryRepository {}

void main() {
  group('DeliveryBloc Offline-First State Machine Tests', () {
    late MockDeliveryRepository mockRepository;
    late StreamController<bool> connectivityStreamController;

    final testDeliveries = [
      const DeliveryRecord(
        id: 'DEL-201',
        recipientName: 'Test Recipient',
        address: 'Test Address',
        phone: '1234567890',
        status: 'assigned',
        syncStatus: SyncStatus.synced,
      ),
    ];

    setUp(() {
      mockRepository = MockDeliveryRepository();
      connectivityStreamController = StreamController<bool>.broadcast();
      when(() => mockRepository.isConnectedStream).thenAnswer((_) => connectivityStreamController.stream);
    });

    tearDown(() {
      connectivityStreamController.close();
    });

    test('initial state is DeliveryInitial', () {
      final bloc = DeliveryBloc(deliveryRepository: mockRepository);
      expect(bloc.state, const DeliveryInitial());
      bloc.close();
    });

    blocTest<DeliveryBloc, DeliveryState>(
      'emits [DeliveryLoading, DeliveryLoaded] when LoadDeliveriesEvent is added',
      build: () {
        when(() => mockRepository.getDeliveries()).thenAnswer((_) async => testDeliveries);
        return DeliveryBloc(deliveryRepository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadDeliveriesEvent()),
      expect: () => [
        const DeliveryLoading(),
        DeliveryLoaded(
          deliveries: testDeliveries,
          pendingSyncCount: 0,
        ),
      ],
    );

    blocTest<DeliveryBloc, DeliveryState>(
      'auto-triggers sync when network transitions from offline to online',
      build: () {
        when(() => mockRepository.syncPendingDeliveries()).thenAnswer((_) async => 1);
        when(() => mockRepository.getDeliveries()).thenAnswer((_) async => testDeliveries);
        return DeliveryBloc(deliveryRepository: mockRepository);
      },
      seed: () => const DeliveryLoaded(
        deliveries: [
          DeliveryRecord(
            id: 'DEL-201',
            recipientName: 'Test',
            address: 'Addr',
            phone: '123',
            status: 'completed',
            syncStatus: SyncStatus.pending,
          ),
        ],
        isConnected: false,
        pendingSyncCount: 1,
      ),
      act: (bloc) => bloc.add(const NetworkStatusChangedEvent(true)),
      expect: () => [
        // 1. Emits online status
        isA<DeliveryLoaded>()
            .having((s) => s.isConnected, 'isConnected', true)
            .having((s) => s.lastSyncMessage, 'message', 'Internet restored.'),
        // 2. Begins syncing
        isA<DeliveryLoaded>().having((s) => s.isSyncing, 'isSyncing', true),
        // 3. Completes sync with 0 pending
        isA<DeliveryLoaded>()
            .having((s) => s.isSyncing, 'isSyncing', false)
            .having((s) => s.pendingSyncCount, 'pendingSyncCount', 0),
      ],
    );
  });
}
