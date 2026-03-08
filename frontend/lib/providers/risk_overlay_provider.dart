import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/constants.dart';

// Provides a list of high-risk map segments fetched from backend
final riskOverlayProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = Dio();
  try {
    // Assuming backend will have this endpoint in routers/graph.py
    final response = await dio.get('${AppConstants.baseUrl}/graph/risk-areas');
    return response.data['risks'] as List<dynamic>;
  } catch (e) {
    // Risk overlay fetch failed
    return [];
  }
});
