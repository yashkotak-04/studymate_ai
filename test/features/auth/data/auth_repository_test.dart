import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:studymate_ai/features/auth/data/auth_repository.dart';
import 'package:studymate_ai/features/profile/data/user_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUserRepository mockUserRepository;
  late AuthRepository authRepository;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockUserRepository = MockUserRepository();
    authRepository = AuthRepository(mockFirebaseAuth, mockUserRepository);
  });

  group('AuthRepository', () {
    test('signIn calls signInWithEmailAndPassword on FirebaseAuth', () async {
      const email = 'test@example.com';
      const password = 'password123';

      when(
        () => mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
      ).thenAnswer((_) async => MockUserCredential());

      await authRepository.signIn(email, password);

      verify(
        () => mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
      ).called(1);
    });

    test(
      'signUp calls createUserWithEmailAndPassword on FirebaseAuth',
      () async {
        const email = 'test@example.com';
        const password = 'password123';

        when(
          () => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          ),
        ).thenAnswer((_) async => MockUserCredential());

        await authRepository.signUp(email, password);

        verify(
          () => mockFirebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          ),
        ).called(1);
      },
    );

    test('signOut calls signOut on FirebaseAuth', () async {
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

      await authRepository.signOut();

      verify(() => mockFirebaseAuth.signOut()).called(1);
    });

    test('authStateChanges returns stream from FirebaseAuth', () {
      final mockUser = MockUser();
      when(
        () => mockFirebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream.value(mockUser));

      final stream = authRepository.authStateChanges();

      expect(stream, emitsInOrder([mockUser]));
    });
  });
}
