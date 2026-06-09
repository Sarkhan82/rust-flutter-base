import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rust_flutter_base/core/error/failure.dart';
import 'package:rust_flutter_base/core/error/result.dart';
import 'package:rust_flutter_base/features/greeting/data/repositories/greeting_repository_impl.dart';
import 'package:rust_flutter_base/features/greeting/data/services/rust_greeting_service.dart';
import 'package:rust_flutter_base/features/greeting/domain/entities/greeting.dart';

class _MockService extends Mock implements RustGreetingService {}

void main() {
  late _MockService service;
  late GreetingRepositoryImpl repo;

  setUp(() {
    service = _MockService();
    repo = GreetingRepositoryImpl(service);
  });

  test('mappe la réponse du service en Ok<Greeting>', () async {
    when(() => service.greet('Ada')).thenAnswer((_) async => 'Hello Ada');

    final result = await repo.fetchGreeting('Ada');

    expect(result, isA<Ok<Greeting>>());
    expect((result as Ok<Greeting>).value.message, 'Hello Ada');
  });

  test('convertit une exception en Err<RustFailure> (pas de fuite)', () async {
    when(() => service.greet(any())).thenThrow(Exception('boom'));

    final result = await repo.fetchGreeting('Ada');

    expect(result, isA<Err<Greeting>>());
    expect((result as Err<Greeting>).failure, isA<RustFailure>());
  });
}
