import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000';
  static String get wsUrl => dotenv.env['WS_BASE_URL'] ?? 'ws://127.0.0.1:8000';
}
