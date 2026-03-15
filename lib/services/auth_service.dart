import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      await _firestore.collection('users').doc(credential.user?.uid).set({
        'uid': credential.user?.uid,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'profileCompleted': false,
      });
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> saveUserDetails({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  Future<void> completeUserProfile({
    required String uid,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      // Add profile completion metadata
      final completeData = {
        ...profileData,
        'profileCompleted': true,
        'profileCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection('users').doc(uid).update(completeData);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}
