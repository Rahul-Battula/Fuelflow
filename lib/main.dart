import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'models/user_model.dart';
import 'services/auth/auth_provider.dart';
import 'services/firestore/user_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/owner_dashboard_screen.dart';
import 'services/theme_provider.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Loaded before the first frame so the saved theme applies without a flash.
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    // Preferences unavailable — the app still runs, the theme just isn't remembered.
  }

  runApp(ProviderScope(
    retry: _retry,
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const MyApp(),
  ));
}

/// Riverpod retries failed providers (with a loading spinner) for ~40 s by
/// default. A Firestore "permission-denied" never succeeds on retry, so fail
/// fast and let the screen show its error message; everything else (e.g.
/// network drops) keeps the default retry behaviour.
Duration? _retry(int retryCount, Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'FuelFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.latteTheme,
      darkTheme: AppTheme.mochaTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (firebaseUser) {
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        final profileAsync = ref.watch(currentUserProfileProvider);

        return profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const _MessageScreen(message: 'Your account has no profile set up.\nContact your administrator.');
            }

            if (profile.status == UserStatus.disabled) {
              return const _MessageScreen(message: 'This account has been disabled.\nContact your administrator.');
            }

            if (profile.role == UserRole.owner) {
              return OwnerDashboardScreen(profile: profile);
            }

            // Staff dashboard placeholder — built in Phase 9.
            return Scaffold(body: Center(child: Text('Staff dashboard for ${profile.name} — coming soon')));
          },
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(body: Center(child: Text('Error loading profile: $err'))),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

class _MessageScreen extends StatelessWidget {
  final String message;
  const _MessageScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
