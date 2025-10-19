import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'models/user.dart';

void main() {
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
      title: 'Game Collection',
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
      ),
      home: _isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _currentUser == null
              ? LoginScreen(onLoginSuccess: _onLoginSuccess)
              : HomeScreen(user: _currentUser!, onLogout: _onLogout),
    );
  }
}