import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ridetrack/features/delivery_sync/domain/entities/delivery_record.dart';
import 'package:ridetrack/features/delivery_sync/domain/entities/sync_status.dart';
import 'package:ridetrack/features/delivery_sync/presentation/bloc/delivery_bloc.dart';
import 'package:ridetrack/features/delivery_sync/presentation/bloc/delivery_state.dart';
import 'package:ridetrack/features/delivery_sync/presentation/screens/delivery_list_screen.dart';

class MockDeliveryBloc extends Mock implements DeliveryBloc {}

void main() {
  late MockDeliveryBloc mockDeliveryBloc;

  setUp(() {
    mockDeliveryBloc = MockDeliveryBloc();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: BlocProvider<DeliveryBloc>.value(
        value: mockDeliveryBloc,
        child: const DeliveryListScreen(),
      ),
    );
  }

  testWidgets('renders deliveries list with sync status badge and recipient name', (tester) async {
    final deliveries = [
      const DeliveryRecord(
        id: 'DEL-201',
        recipientName: 'Rahul Verma',
        address: 'Connaught Place Block B',
        phone: '+91 9876543210',
        status: 'assigned',
        syncStatus: SyncStatus.pending,
      ),
      const DeliveryRecord(
        id: 'DEL-202',
        recipientName: 'Sneha Patel',
        address: 'KG Marg Tower A',
        phone: '+91 9123456789',
        status: 'completed',
        syncStatus: SyncStatus.synced,
      ),
    ];

    when(() => mockDeliveryBloc.state).thenReturn(
      DeliveryLoaded(
        deliveries: deliveries,
        isConnected: true,
        pendingSyncCount: 1,
        lastSyncMessage: 'Online • Auto-sync active',
      ),
    );
    when(() => mockDeliveryBloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(buildTestWidget());

    expect(find.text('Field Deliveries & Sync Queue'), findsOneWidget);
    expect(find.text('DEL-201'), findsOneWidget);
    expect(find.text('Rahul Verma'), findsOneWidget);
    expect(find.text('Pending Sync'), findsOneWidget);
    expect(find.text('DEL-202'), findsOneWidget);
    expect(find.text('Sneha Patel'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('1 Pending'), findsOneWidget);
  });
}
