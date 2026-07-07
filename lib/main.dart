import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'features/manager/screens/manager_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      databaseURL: String.fromEnvironment('FIREBASE_DATABASE_URL'),
    ),
  );

  runApp(const ProviderScope(child: MusiCifrasApp()));
}

class MusiCifrasApp extends ConsumerWidget {
  const MusiCifrasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'MusiCifras',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.managerTheme,
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const ManagerScreen();
          }
          return const LoginScreen();
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Text('Erro: $err'),
          ),
        ),
      ),
    );
  }
}
