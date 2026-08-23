import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/chat_model.dart';
import '../../auth/data/auth_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(FirebaseFirestore.instance);
});

// Stream provider for user's chat threads
final userChatThreadsProvider = StreamProvider<List<ChatThread>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  return ref.watch(chatRepositoryProvider).getUserThreads(user.uid);
});

// Stream provider for messages in a specific thread
final threadMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, threadId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || threadId.isEmpty) return Stream.value([]);
  
  return ref.watch(chatRepositoryProvider).getThreadMessages(user.uid, threadId);
});

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository(this._firestore);

  Stream<List<ChatThread>> getUserThreads(String userId, {int limit = 50}) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chatThreads')
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatThread.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<List<ChatMessage>> getThreadMessages(String userId, String threadId, {int limit = 100}) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chatThreads')
        .doc(threadId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<String> createThread(
    String userId,
    String subjectId,
    String title, {
    ExplanationMode mode = ExplanationMode.student,
  }) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('chatThreads')
        .doc();
        
    final thread = ChatThread(
      id: docRef.id,
      userId: userId,
      subjectId: subjectId,
      title: title,
      mode: mode,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await docRef.set(thread.toJson());
    return docRef.id;
  }

  Future<void> addMessage(String userId, String threadId, ChatMessage message) async {
    final threadRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('chatThreads')
        .doc(threadId);
        
    final batch = _firestore.batch();
    
    // Add message
    final messageRef = threadRef.collection('messages').doc(message.id.isNotEmpty && message.id != 'temp' ? message.id : null);
    batch.set(messageRef, message.toJson());
    
    // Update thread timestamp and preview
    final preview = message.text.length > 80 ? '${message.text.substring(0, 80)}...' : message.text;
    batch.update(threadRef, {
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': preview,
    });
    
    await batch.commit();
  }

  Future<void> updateThreadMode(String userId, String threadId, ExplanationMode mode) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('chatThreads')
        .doc(threadId)
        .update({
      'mode': mode.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteThread(String userId, String threadId) async {
    final threadRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('chatThreads')
        .doc(threadId);

    // Delete nested messages first
    final messages = await threadRef.collection('messages').get();
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(threadRef);
    await batch.commit();
  }
}
