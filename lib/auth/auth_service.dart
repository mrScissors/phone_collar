// auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Asynchronous initialization of Firebase Auth.
  ///
  /// This method listens for the first authentication state change event,
  /// ensuring that the auth state is fully loaded.
  Future<void> initialize() async {
    await _auth.authStateChanges().first;
  }

  // Sign in with email and password
  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() {
    return _auth.signOut();
  }
}
