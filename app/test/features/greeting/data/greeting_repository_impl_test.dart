import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rust_flutter_base/core/error/failure.dart';
import 'package:rust_flutter_base/core/error/result.dart';
import 'package:rust_flutter_base/core/observability/logger.dart';
import 'package:rust_flutter_base/features/greeting/data/datasources/greeting_remote_data_source.dart';
import 'package:rust_flutter_base/features/greeting/data/repositories/greeting_repository_impl.dart';
import 'package:rust_flutter_base/features/greeting/domain/entities/greeting.dart';

class _MockDataSource extends Mock implements GreetingRemoteDataSource {}

void main() {
  late _MockDataSource dataSource;
  late GreetingRepositoryImpl repo;

  setUp(() {
    dataSource = _MockDataSource();
    repo = GreetingRepositoryImpl(dataSource, const AppLogger());
  });

  test('mappe la réponse de la datasource en Ok<Greeting>', () async {
    when(() => dataSource.fetchGreeting('Ada'))
        .thenAnswer((_) async => 'Bonjour, Ada ! 👋');

    final result = await repo.fetchGreeting('Ada');

    expect(result, isA<Ok<Greeting>>());
    expect((result as Ok<Greeting>).value.message, 'Bonjour, Ada ! 👋');
  });

  test('convertit une DioException en NetworkFailure typé (pas de fuite)',
      () async {
    when(() => dataSource.fetchGreeting(any())).thenThrow(
      DioException.connectionError(
        requestOptions: RequestOptions(path: '/api/v1/greeting'),
        reason: 'connection refused',
      ),
    );

    final result = await repo.fetchGreeting('Ada');

    expect(result, isA<Err<Greeting>>());
    expect(
      (result as Err<Greeting>).failure,
      const NetworkFailure(NetworkFailureKind.connection),
    );
  });

  test('porte le status HTTP sur une réponse en erreur (badResponse)',
      () async {
    final requestOptions = RequestOptions(path: '/api/v1/greeting');
    when(() => dataSource.fetchGreeting(any())).thenThrow(
      DioException.badResponse(
        statusCode: 503,
        requestOptions: requestOptions,
        response: Response<void>(
          requestOptions: requestOptions,
          statusCode: 503,
        ),
      ),
    );

    final result = await repo.fetchGreeting('Ada');

    expect(
      (result as Err<Greeting>).failure,
      const NetworkFailure(NetworkFailureKind.badResponse, statusCode: 503),
    );
  });

  test('convertit une réponse malformée en NetworkFailure(malformedResponse)',
      () async {
    when(() => dataSource.fetchGreeting(any()))
        .thenThrow(const FormatException('champ message absent'));

    final result = await repo.fetchGreeting('Ada');

    expect(result, isA<Err<Greeting>>());
    expect(
      (result as Err<Greeting>).failure,
      const NetworkFailure(NetworkFailureKind.malformedResponse),
    );
  });

  test('filet de sécurité : exception inattendue → UnexpectedFailure',
      () async {
    when(() => dataSource.fetchGreeting(any())).thenThrow(Exception('boom'));

    final result = await repo.fetchGreeting('Ada');

    expect(result, isA<Err<Greeting>>());
    expect((result as Err<Greeting>).failure, const UnexpectedFailure());
  });
}
