import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config/config.dart';
import '../../mia/mia.dart';
import 'login_screen.dart';

/// Entry into the Mia task assistant (after the home page).
/// Prefer [Mia.open] from parent surfaces; this gate resolves auth first.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    // Sign-in paused for local testing. LoginScreen + AuthService remain.
    if (AppConfig.skipSignIn) {
      final uid = auth.currentUser?.uid ?? AppConfig.guestUid;
      return Mia.root(auth: auth, uid: uid);
    }

    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(auth: auth);
        }
        return Mia.root(auth: auth, uid: user.uid);
      },
    );
  }
}
