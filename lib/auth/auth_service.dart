import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user UID
  String? get currentUserId => _auth.currentUser?.uid;

  // Register new user
  Future<User?> registerUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      log("User registered successfully: ${cred.user?.uid}");
      return cred.user;
    } on FirebaseAuthException catch (e) {
      log("Registration error: ${e.code} - ${e.message}");
      rethrow; // Re-throw to handle in UI
    } catch (e) {
      log("Unexpected registration error: $e");
      rethrow;
    }
  }

  // Login user
  Future<User?> loginUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      log("User logged in successfully: ${cred.user?.uid}");
      return cred.user;
    } on FirebaseAuthException catch (e) {
      log("Login error: ${e.code} - ${e.message}");
      rethrow; // Re-throw to handle specific errors in UI
    } catch (e) {
      log("Unexpected login error: $e");
      rethrow;
    }
  }

  // Get user profile using current authenticated user's UID
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        log("No user authenticated");
        return null;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        log("Profile found for user: ${user.uid}");
        return doc.data();
      } else {
        log("No profile found for user: ${user.uid}");
        return null;
      }
    } catch (e) {
      log("Error getting user profile: $e");
      return null;
    }
  }

  // Check if profile exists using current authenticated user's UID
  Future<bool> checkProfileExists(String uid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        log("No user authenticated to check profile");
        return false;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      final exists = doc.exists;

      log("Profile exists check for ${user.uid}: $exists");
      return exists;
    } catch (e) {
      log("Error checking profile existence: $e");
      return false;
    }
  }

  // Create or update user profile with Auth UID
  Future<bool> createUserProfile(Map<String, dynamic> userData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        log("No user authenticated to create profile");
        return false;
      }

      // Ensure the email matches the authenticated user
      if (userData['email'] != user.email) {
        log("Email mismatch between auth and profile data");
        return false;
      }

      // Add metadata to user data
      final completeUserData = {
        ...userData,
        'userId': user.uid, // Store UID as field for reference
        'authProvider': 'email_password',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'emailVerified': user.emailVerified,
      };

      await _firestore.collection('users').doc(user.uid).set(completeUserData);

      log("User profile created/updated successfully for: ${user.uid}");
      return true;
    } catch (e) {
      log("Error creating user profile: $e");
      return false;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        log("No user authenticated to update profile");
        return false;
      }

      final updateData = {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(user.uid).update(updateData);

      log("User profile updated successfully for: ${user.uid}");
      return true;
    } catch (e) {
      log("Error updating user profile: $e");
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      log("User signed out successfully");
    } catch (e) {
      log("Error signing out: $e");
      rethrow;
    }
  }

  // Get user data stream for real-time updates
  Stream<DocumentSnapshot> get userProfileStream {
    final user = _auth.currentUser;
    if (user == null) {
      log("No user authenticated for profile stream");
      return const Stream.empty();
    }

    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  // Get user progress stream
  Stream<DocumentSnapshot> getUserProgressStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore.collection('user_progress').doc(user.uid).snapshots();
  }

  // Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  // Get authentication state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user's email
  String? get currentUserEmail => _auth.currentUser?.email;

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        log("Email verification sent");
      }
    } catch (e) {
      log("Error sending email verification: $e");
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      log("Password reset email sent to: $email");
    } catch (e) {
      log("Error sending password reset: $e");
      rethrow;
    }
  }

  // Delete user account and profile
  Future<bool> deleteUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Delete user profile from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete user progress
      await _firestore.collection('user_progress').doc(user.uid).delete();

      // Delete authentication account
      await user.delete();

      log("User account and data deleted successfully");
      return true;
    } catch (e) {
      log("Error deleting user account: $e");
      return false;
    }
  }

  // Re-authenticate user (for sensitive operations)
  Future<bool> reAuthenticate(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      log("Re-authentication failed: $e");
      return false;
    }
  }
}
