import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rust_flutter_base/core/error/failure.dart';
import 'package:rust_flutter_base/core/error/result.dart';
import 'package:rust_flutter_base/features/greeting/domain/entities/greeting.dart';
import 'package:rust_flutter_base/features/greeting/domain/repositories/greeting_repository.dart';
import 'package:rust_flutter_base/features/greeting/domain/usecases/get_greeting.dart';

class _MockRepo extends Mock implements GreetingRepository {}

void main() {
  late _MockRepo repo;
  late GetGreeting usecase;

  setUp(() {
    repo = _MockRepo();
    usecase = GetGreeting(repo);
  });

  test('renvoie ValidationFailure si le nom est vide, sans appeler le repo',
      () async {
    final result = await usecase('   ');

    expect(result, isA<Err<Greeting>>());
    expect((result as Err<Greeting>).failure, isA<ValidationFailure>());
    verifyNever(() => repo.fetchGreeting(any()));
  });

  test('délègue le nom (trimmé) au repository sur input valide', () async {
    const greeting = Greeting(message: 'hi');
    when(() => repo.fetchGreeting('Ada'))
        .thenAnswer((_) async => const Ok(greeting));

    final result = await usecase('  Ada  ');

    expect(result, isA<Ok<Greeting>>());
    expect((result as Ok<Greeting>).value, greeting);
    verify(() => repo.fetchGreeting('Ada')).called(1);
  });
}
