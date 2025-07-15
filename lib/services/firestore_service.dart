import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final CollectionReference users = FirebaseFirestore.instance.collection('users');

  Future<void> createUserProfile(Map<String, dynamic> userData) async {
    await users.add(userData);
  }

  Future<List<Map<String, dynamic>>> getUserProfiles() async {
    final snapshot = await users.get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<void> updateUserProfile(String docId, Map<String, dynamic> newData) async {
    await users.doc(docId).update(newData);
  }

  Future<void> deleteUserProfile(String docId) async {
    await users.doc(docId).delete();
  }
}
