// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'models/user.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style to match theme
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  User? _currentUser;
  bool _isLoading = true;
  bool _orientationSet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuth();
    _setOrientation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!_orientationSet) {
      _setOrientation();
    }
  }

  void _setOrientation() {
    if (_orientationSet) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final physicalSize = view.physicalSize;
      
      final physicalWidth = physicalSize.width;
      final physicalHeight = physicalSize.height;

      if (physicalWidth > physicalHeight) {
        // Device is naturally wider - lock to portrait
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else {
        // Device is naturally taller - lock to landscape
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
      
      _orientationSet = true;
    });
  }

  Future<void> _checkAuth() async {
    final result = await AuthService.verifyToken();
    setState(() {
      if (result['success']) {
        _currentUser = User.fromJson(result['user']);
      }
      _isLoading = false;
    });
  }

  void _onLoginSuccess(User user) {
    setState(() => _currentUser = user);
  }

  void _onLogout() {
    AuthService.signOut();
    setState(() => _currentUser = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microvark Gaming',  // Using the brand name from report
      debugShowCheckedModeBanner: false,
      
      // Apply the new theme following report specifications
      theme: AppTheme.darkTheme,
      
      home: _isLoading
          ? Scaffold(
              backgroundColor: AppColors.primaryNavy,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accentElectricBlue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _currentUser == null
              ? LoginScreen(onLoginSuccess: _onLoginSuccess)
              : HomeScreen(user: _currentUser!, onLogout: _onLogout),
    );
  }
}