import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import '../core/constants.dart';

class OpenSkyService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  Future<List<Map<String, dynamic>>> fetchAircraft(LatLngBounds bounds) async {
    try {
      final lamin = bounds.south;
      final lamax = bounds.north;
      final lomin = bounds.west;
      final lomax = bounds.east;

      // Use our backend proxy to bypass CORS
      final url = '${AppConstants.baseUrl}/api/aircraft?lamin=$lamin&lomin=$lomin&lamax=$lamax&lomax=$lomax';
      
      final response = await _dio.get(url);
      
      if (response.statusCode == 200 && response.data != null) {
        final states = response.data['states'] as List<dynamic>?;
        if (states == null) return [];

        final aircraft = <Map<String, dynamic>>[];
        
        // Limit to 50 planes max to avoid map lag
        final limit = states.length > 50 ? 50 : states.length;
        
        for (int i = 0; i < limit; i++) {
          final state = states[i];
          if (state == null) continue;
          
          final lon = state[5];
          final lat = state[6];
          final heading = state[10];
          
          if (lon != null && lat != null && heading != null) {
            // Keep data simple and serializable
            aircraft.add({
              'lon': lon is num ? lon.toDouble() : 0.0,
              'lat': lat is num ? lat.toDouble() : 0.0,
              'heading': heading is num ? heading.toDouble() : 0.0,
            });
          }
        }
        return aircraft;
      }
      return [];
    } catch (e) {
      // Silently fail API errors or rate limits for background overlays
      return [];
    }
  }
}
