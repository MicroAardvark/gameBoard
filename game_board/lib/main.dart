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
  
  // Lock to landscape orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
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

class _MyAppState extends State<MyApp> {
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
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
      title: 'Microvark Gaming',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _isLoading
          ? const Scaffold(
              backgroundColor: AppColors.primaryNavyDark,
              body: Center(
                child: CircularProgressIndicator(
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