// ignore_for_file: subtype_of_sealed_class
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studymate_ai/features/profile/data/user_repository.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockUser extends Mock implements User {}

class FakeSetOptions extends Fake implements SetOptions {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocument;
  late MockDocumentSnapshot mockSnapshot;
  late MockUser mockUser;
  late UserRepository userRepository;

  setUpAll(() {
    registerFallbackValue(FakeSetOptions());
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocument = MockDocumentReference();
    mockSnapshot = MockDocumentSnapshot();
    mockUser = MockUser();

    when(() => mockFirestore.collection('users')).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocument);
    when(() => mockDocument.get()).thenAnswer((_) async => mockSnapshot);
    when(() => mockSnapshot.exists).thenReturn(false);
    when(() => mockUser.uid).thenReturn('test_uid');
    when(() => mockUser.email).thenReturn('test@example.com');
    when(() => mockUser.displayName).thenReturn('Test User');

    userRepository = UserRepository(mockFirestore);
  });

  group('UserRepository', () {
    test('createUserProfile sets user document in firestore', () async {
      when(() => mockDocument.set(any(), any())).thenAnswer((_) async {});

      await userRepository.createUserProfile(mockUser);

      verify(
        () => mockDocument.set(any(that: isA<Map<String, dynamic>>()), any()),
      ).called(1);
    });
  });
}
