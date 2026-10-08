import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/vault_provider.dart';
import 'providers/security_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/biometric_lock_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/api_service.dart';

import 'core/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: ApiService.supabaseUrl,
      publishableKey: ApiService.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint("Supabase init error: $e");
  }

  // Asynchronous fire-and-forget ping to wake up Render backend immediately
  ApiService().initCustomUrl().then((_) {
    ApiService().pingServer();
  });

  runApp(const SecureVaultApp());
}

class SecureVaultApp extends StatefulWidget {
  const SecureVaultApp({super.key});

  @override
  State<SecureVaultApp> createState() => _SecureVaultAppState();
}

class _SecureVaultAppState extends State<SecureVaultApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User returned to the app: ensure backend container is awake
      ApiService().pingServer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => SecurityNotificationService()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          Widget initialScreen;
          if (!auth.isAuthenticated) {
            initialScreen = const LoginScreen();
          } else if (auth.isBiometricLocked) {
            initialScreen = BiometricLockScreen(
              onUnlocked: () => auth.unlockBiometric(),
              onFallbackToPassword: () => auth.logout(),
            );
          } else {
            initialScreen = const MainNavigationScreen();
          }

          return MaterialApp(
            title: 'SecureVault AI',
            navigatorKey: SecurityNotificationService.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: VaultTheme.classicTheme,
            home: initialScreen,
          );
        },
      ),
    );
  }
}
