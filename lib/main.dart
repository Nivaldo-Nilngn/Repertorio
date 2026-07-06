import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'features/manager/screens/manager_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBGlRJagmiZSTCEu6EGriJpxOt4tBEkbA4",
      authDomain: "songbooknil.firebaseapp.com",
      projectId: "songbooknil",
      storageBucket: "songbooknil.firebasestorage.app",
      messagingSenderId: "367329738936",
      appId: "1:367329738936:web:1dc3168dc9e00569d0744d",
      databaseURL: "https://songbooknil-default-rtdb.firebaseio.com",
    ),
  );

  runApp(const ProviderScope(child: MusiCifrasApp()));
}

class MusiCifrasApp extends StatelessWidget {
  const MusiCifrasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MusiCifras',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.managerTheme,
      home: const ManagerScreen(),
    );
  }
}
