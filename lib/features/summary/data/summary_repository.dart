import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/summary_model.dart';
import '../../auth/data/auth_repository.dart';

final summaryRepositoryProvider = Provider<SummaryRepository>((ref) {
  return SummaryRepository(FirebaseFirestore.instance);
});

// Stream provider for user's summaries
final userSummariesProvider = StreamProvider<List<SummaryDocument>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return ref.watch(summaryRepositoryProvider).getUserSummaries(user.uid);
});

class SummaryRepository {
  final FirebaseFirestore _firestore;

  SummaryRepository(this._firestore);

  Stream<List<SummaryDocument>> getUserSummaries(
    String userId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('summaries')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SummaryDocument.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<SummaryDocument?> getSummary(String userId, String summaryId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('summaries')
        .doc(summaryId)
        .get();

    if (doc.exists && doc.data() != null) {
      return SummaryDocument.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  Future<String> saveSummary(SummaryDocument summary) async {
    final docRef = _firestore
        .collection('users')
        .doc(summary.userId)
        .collection('summaries')
        .doc(summary.id.isNotEmpty ? summary.id : null);

    final data = summary.toJson();
    await docRef.set(data, SetOptions(merge: true));
    return docRef.id;
  }

  Future<void> deleteSummary(String userId, String summaryId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('summaries')
        .doc(summaryId)
        .delete();
  }
}
