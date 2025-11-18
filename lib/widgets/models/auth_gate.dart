import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../screens/home_screen.dart';
import '../../screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    print("🚪 AuthGate building...");
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print("🔄 Auth State: ${snapshot.connectionState}, Has Data: ${snapshot.hasData}");

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Loading Auth State..."), // Visual debug text
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          print("✅ User logged in: ${snapshot.data?.email}");
          return const HomeScreen();
        }

        print("👤 User logged out, showing LoginScreen");
        return const LoginScreen();
      },
    );
  }
}