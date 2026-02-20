// ====================================
// lib/main.dart
// Application entry point and root widget
//
// PURPOSE:
//   Bootstraps the Microvark Gaming Platform, configures device-level settings
//   (orientation lock and system UI styling), and acts as the top-level
//   authentication router.  All navigation decisions for first-launch vs
//   returning authenticated users are made here so no other screen needs to
//   concern itself with auth state.
//
// RESPONSIBILITIES:
//   - Locking the app to landscape orientation (suited to card/board games)
//   - Matching the status bar and navigation bar colours to the app theme
//   - Silently verifying the stored JWT token on startup via [AuthService]
//   - Routing to [LoginScreen] (unauthenticated) or [HomeScreen] (authenticated)
//   - Exposing [_onLoginSuccess] and [_onLogout] callbacks to child screens
//     so auth-state changes bubble back up to the root without a state-management
//     library
//
// AUTH FLOW:
//   App start
//     │
//     ├─ Token present + valid  ──► HomeScreen (persisted session)
//     ├─ Token absent / expired ──► LoginScreen
//     └─ Verification in progress ► Loading spinner (CircularProgressIndicator)
// ====================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'models/user.dart';
import 'theme/app_theme.dart';

/// Application entry point.
///
/// [WidgetsFlutterBinding.ensureInitialized] must be called before any
/// platform-channel operations (e.g. [SystemChrome]) so the binding between
/// the Flutter engine and the widget layer is fully established.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientation Lock ────────────────────────────────────────────────────
  // Force landscape-only mode.  Card and board games benefit from the wider
  // aspect ratio, and the Blackjack table layout is designed for landscape.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ── System UI Styling ───────────────────────────────────────────────────
  // Make the status bar transparent so the app's dark navy background shows
  // through, and use light icons so they remain visible on the dark surface.
  // The navigation bar is tinted to match [AppColors.primaryNavyDark] for a
  // seamless edge-to-edge appearance.
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.primaryNavyDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

/// Root widget of the Microvark Gaming Platform.
///
/// Implemented as a [StatefulWidget] because it owns the global authentication
/// state ([_currentUser]) that must survive widget rebuilds and be propagated
/// down the tree to [HomeScreen] and [LoginScreen].
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ─── State ────────────────────────────────────────────────────────────────

  /// The currently authenticated user, or `null` when not signed in.
  /// Drives the [build] method's routing decision.
  User? _currentUser;

  /// `true` whilst [_checkAuth] is awaiting the token verification response.
  /// A loading spinner is displayed during this window to prevent a flash of
  /// the login screen for users with valid persisted sessions.
  bool _isLoading = true;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  // ─── Auth Logic ───────────────────────────────────────────────────────────

  /// Checks whether a valid JWT token is stored on the device.
  ///
  /// [AuthService.verifyToken] reads the token from secure storage and
  /// validates it against the backend.  If valid, the decoded user payload is
  /// used to hydrate [_currentUser] so the session persists across cold
  /// launches without requiring the player to log in again.
  ///
  /// On completion (success or failure), [_isLoading] is set to `false` so
  /// the build method transitions from the loading spinner to the appropriate
  /// screen.
  Future<void> _checkAuth() async {
    final result = await AuthService.verifyToken();
    setState(() {
      if (result['success']) {
        // Hydrate the user model from the verified token payload.
        _currentUser = User.fromJson(result['user']);
      }
      // Always clear the loading flag, even if verification failed.
      _isLoading = false;
    });
  }

  /// Called by [LoginScreen] after a successful sign-in.
  ///
  /// Stores the authenticated [user] in state, which triggers a rebuild and
  /// routes to [HomeScreen].
  void _onLoginSuccess(User user) {
    setState(() => _currentUser = user);
  }

  /// Called by [HomeScreen] when the player signs out.
  ///
  /// Clears the stored token via [AuthService.signOut] and sets [_currentUser]
  /// to `null`, routing back to [LoginScreen].
  void _onLogout() {
    AuthService.signOut();
    setState(() => _currentUser = null);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microvark Gaming',

      // Remove the debug banner so it does not appear in screenshots or
      // when demoing the app.
      debugShowCheckedModeBanner: false,

      // Apply the centralised dark theme (defined in AppTheme) so all
      // Material widgets automatically inherit the correct colours and fonts.
      theme: AppTheme.darkTheme,

      // ── Routing ───────────────────────────────────────────────────────────
      // Three possible states, evaluated in priority order:
      //
      //   1. _isLoading   → Show a centred loading spinner while the token is
      //                     being verified.  Prevents a login-screen flash for
      //                     returning authenticated users.
      //
      //   2. No user      → Show LoginScreen and pass the success callback so
      //                     it can update this widget's state on sign-in.
      //
      //   3. User present → Show HomeScreen, providing the user model and the
      //                     logout callback.
      home: _isLoading
          ? const Scaffold(
              backgroundColor: AppColors.primaryNavyDark,
              body: Center(
                child: CircularProgressIndicator(
                  // Electric blue spinner on the dark navy background matches
                  // the app's accent colour scheme.
                  color: AppColors.accentElectricBlue,
                ),
              ),
            )
          : _currentUser == null
              ? LoginScreen(onLoginSuccess: _onLoginSuccess)
              : HomeScreen(user: _currentUser!, onLogout: _onLogout),
    );
  }
}