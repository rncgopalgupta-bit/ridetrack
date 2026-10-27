import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ridetrack/features/camera/domain/usecases/process_pod_image.dart';
import 'package:ridetrack/features/camera/presentation/bloc/camera_bloc.dart';
import 'package:ridetrack/features/camera/presentation/bloc/camera_event.dart';
import 'package:ridetrack/features/camera/presentation/bloc/camera_state.dart';
import 'package:ridetrack/features/delivery_sync/data/datasources/delivery_local_datasource.dart';

class MockProcessPodImageUseCase extends Mock implements ProcessPodImageUseCase {}
class MockDeliveryLocalDataSource extends Mock implements IDeliveryLocalDataSource {}

void main() {
  group('CameraBloc Unit Tests', () {
    late MockProcessPodImageUseCase mockProcessImageUseCase;
    late MockDeliveryLocalDataSource mockDeliveryLocalDataSource;

    setUp(() {
      mockProcessImageUseCase = MockProcessPodImageUseCase();
      mockDeliveryLocalDataSource = MockDeliveryLocalDataSource();
    });

    test('initial state is CameraInitial', () {
      final bloc = CameraBloc(
        processImageUseCase: mockProcessImageUseCase,
        deliveryLocalDataSource: mockDeliveryLocalDataSource,
      );
      expect(bloc.state, const CameraInitial());
      bloc.close();
    });

    blocTest<CameraBloc, CameraState>(
      'emits [CameraReady] when InitializeCameraEvent is added',
      build: () => CameraBloc(
        processImageUseCase: mockProcessImageUseCase,
        deliveryLocalDataSource: mockDeliveryLocalDataSource,
      ),
      act: (bloc) => bloc.add(const InitializeCameraEvent()),
      expect: () => [
        const CameraReady(),
      ],
    );
  });
}
