import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/settings_provider.dart';
import 'features/manager/screens/manager_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');

  if (apiKey.isEmpty || projectId.isEmpty || appId.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    // Ignore, in case it's already set or not supported
  }

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const KordApp(),
    ),
  );
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFFB74D), size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Variáveis de ambiente não configuradas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Rode localmente com:\n\nflutter run -d chrome \\\n  --dart-define=FIREBASE_API_KEY=... \\\n  --dart-define=FIREBASE_PROJECT_ID=...\n\nOu configure as variáveis de ambiente no Netlify.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class KordApp extends ConsumerWidget {
  const KordApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final appThemeType = ref.watch(appThemeProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'KordApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.resolveWithCustomSettings(
        appThemeType,
        primaryHex: settings.customThemeColorHex,
        bgHex: settings.customBgColorHex,
        textHex: settings.customTextColorHex,
        fontFamily: settings.fontFamily,
      ),
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const ManagerScreen();
          }
          return const LoginScreen();
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
        ),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Não foi possível conectar ao servidor.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Por favor, verifique sua conexão e tente novamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
