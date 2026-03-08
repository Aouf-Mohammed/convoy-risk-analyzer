import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/constants.dart';

final dioProvider = Provider((ref) => Dio());

class MapState {
  final bool loading;
  final String? error;
  final List<dynamic> routes;
  final String? liveUpdate;
  final Map<String, int> convoyComposition;
  final String? startPoint;
  final String? endPoint;

  MapState({
    this.loading = false,
    this.error,
    this.routes = const [],
    this.liveUpdate,
    this.convoyComposition = const {
      'motorcycle': 0,
      'truck': 1,
      'APC': 0,
      'tank': 0,
      'artillery': 0,
    },
    this.startPoint,
    this.endPoint,
  });

  MapState copyWith({
    bool? loading,
    String? error,
    List<dynamic>? routes,
    String? liveUpdate,
    Map<String, int>? convoyComposition,
    String? startPoint,
    String? endPoint,
  }) {
    return MapState(
      loading: loading ?? this.loading,
      error: error, // Can be null, must be explicitly cleared to remove
      routes: routes ?? this.routes,
      liveUpdate: liveUpdate, // Can be null
      convoyComposition: convoyComposition ?? this.convoyComposition,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
    );
  }

  int get totalVehicles => convoyComposition.values.fold(0, (a, b) => a + b);

  double get convoyRiskMultiplier {
    double total = 0;
    int count = 0;
    final Map<String, double> weights = {
      'motorcycle': 0.1,
      'truck': 0.3,
      'APC': 0.5,
      'tank': 0.8,
      'artillery': 0.9,
    };

    convoyComposition.forEach((type, qty) {
      if (qty > 0) {
        total += (weights[type] ?? 0.3) * qty;
        count += qty;
      }
    });

    if (count == 0) return 1.0;
    double avgWeight = total / count;
    double sizeFactor = 1.0 + (count / 20).clamp(0.0, 0.5);
    return (avgWeight * sizeFactor).clamp(0.5, 2.0);
  }
}

class MapStateNotifier extends StateNotifier<MapState> {
  final Ref ref;
  MapStateNotifier(this.ref) : super(MapState());

  void setPoints(String start, String end) {
    state = state.copyWith(startPoint: start, endPoint: end);
  }

  void updateConvoyComposition(String type, int count) {
    final newComp = Map<String, int>.from(state.convoyComposition);
    newComp[type] = count;
    state = state.copyWith(convoyComposition: newComp);
  }

  void setError(String? error) {
    state = state.copyWith(error: error, loading: false);
  }

  void setLiveUpdate(String? update) {
    state = state.copyWith(liveUpdate: update);
  }

  Future<void> analyzeRoute(String start, String end) async {
    final startParts = start.trim().split(',');
    final endParts = end.trim().split(',');

    if (startParts.length != 2 || endParts.length != 2) {
      setError('Enter coordinates as: lat, lon');
      return;
    }

    if (state.totalVehicles == 0) {
      setError('Add at least one vehicle to the convoy');
      return;
    }

    state = state.copyWith(loading: true, error: null, routes: [], liveUpdate: null);

    final dominantVehicle = state.convoyComposition.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    final dio = ref.read(dioProvider);
    int retries = 3;
    
    while (retries > 0) {
      try {
        final response = await dio.post(
          '${AppConstants.baseUrl}/route/plan',
          data: {
            "origin": [double.parse(startParts[0]), double.parse(startParts[1])],
            "destination": [double.parse(endParts[0]), double.parse(endParts[1])],
            "k": 3,
            "vehicle_type": dominantVehicle,
            "convoy_composition": state.convoyComposition,
            "risk_multiplier": state.convoyRiskMultiplier,
          },
        );

        if (!mounted) return;

        final routes = response.data['routes'] as List;

        for (var route in routes) {
          final original = (route['safety_probability'] as num).toDouble();
          final adjusted = (original / state.convoyRiskMultiplier).clamp(0.0, 1.0);
          route['safety_probability'] = adjusted;
          route['safety_percentage'] = '${(adjusted * 100).toStringAsFixed(2)}%';
        }

        routes.sort(
          (a, b) => (b['safety_probability'] as num).compareTo(
            a['safety_probability'] as num,
          ),
        );

        state = state.copyWith(routes: routes, loading: false);
        return; // Success, exit loop
        
      } catch (e) {
        if (e is DioException && e.response != null && e.response?.statusCode != 500) {
          final detail = e.response?.data['detail'] ?? 'Error fetching routes';
          if (mounted) setError('$detail');
          return; // Don't retry client/business logic errors 
        }
        
        retries--;
        if (retries == 0) {
          if (mounted) {
            setError(e is DioException && e.type == DioExceptionType.connectionError 
                ? '[ SYS_ERROR ] OFFLINE CACHE ENGAGED: $e' 
                : 'Failed to connect to backend: $e');
          }
          return;
        }
        // Exponential backoff: 2s, 4s
        await Future.delayed(Duration(seconds: 2 * (3 - retries)));
      }
    }
  }
}

final mapStateProvider = StateNotifierProvider<MapStateNotifier, MapState>(
  (ref) => MapStateNotifier(ref),
);
