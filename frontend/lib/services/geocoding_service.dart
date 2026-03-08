import 'package:dio/dio.dart';

class PlaceMatch {
  final String name;
  final double lat;
  final double lon;

  PlaceMatch({required this.name, required this.lat, required this.lon});
}

class GeocodingService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      maxRedirects: 3,
    ),
  );
  
  // Coordinate regex: ±90.000, ±180.000
  static final RegExp _coordRegex = RegExp(
    r'^[-+]?([1-8]?\d(\.\d+)?|90(\.0+)?),\s*[-+]?(180(\.0+)?|((1[0-7]\d)|([1-9]?\d))(\.\d+)?)$'
  );

  bool isCoordinate(String query) {
    return _coordRegex.hasMatch(query.trim());
  }

  Future<List<PlaceMatch>> search(String query) async {
    if (query.trim().isEmpty) return [];
    
    // If it's a coordinate, return it as the only option
    if (isCoordinate(query)) {
      final parts = query.split(',');
      final lat = double.tryParse(parts[0].trim());
      final lon = double.tryParse(parts[1].trim());
      if (lat != null && lon != null) {
        return [PlaceMatch(name: 'Coordinate: $lat, $lon', lat: lat, lon: lon)];
      }
    }

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 5,
        },
        options: Options(
          headers: {
            'User-Agent': 'ConvoyRiskAnalyzer/1.0',
          }
        )
      );

      return (response.data as List).map((item) {
        return PlaceMatch(
          name: item['display_name'] as String,
          lat: double.parse(item['lat'] as String),
          lon: double.parse(item['lon'] as String),
        );
      }).toList();
    } catch (e) {
      // Geocoding error
      return [];
    }
  }

  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'format': 'json',
        },
        options: Options(
          headers: {
            'User-Agent': 'ConvoyRiskAnalyzer/1.0',
          }
        )
      );
      return response.data['display_name'] as String?;
    } catch (e) {
      // Reverse geocoding error
      return '$lat, $lon';
    }
  }
}
