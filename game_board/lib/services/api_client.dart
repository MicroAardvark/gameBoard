// lib/services/api_client.dart
import 'package:http/http.dart' as http;

import '../demo/demo_backend.dart';
import '../demo/demo_mode.dart';

/// The one HTTP client every REST call goes through.
///
/// In a normal build this is the platform's own client. In a demo build
/// (--dart-define=DEMO=true) it is [DemoBackend], an in-memory fake of the
/// Node API, so the app never contacts the real server.
final http.Client apiClient = isDemo ? DemoBackend.instance.client : http.Client();
