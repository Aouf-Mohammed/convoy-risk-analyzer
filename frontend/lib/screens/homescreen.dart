import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final MapController _mapController = MapController();
  final Dio _dio = Dio();

  bool _loading = false;
  String? _error;
  List<dynamic> _routes = [];

  final channel = WebSocketChannel.connect(
    Uri.parse('wss://your-railway-url.up.railway.app/ws/risk-updates'),
  );
  // Colors from safest (green) to riskiest (red)
  final List<Color> _routeColors = [Colors.green, Colors.orange, Colors.red];

  Future<void> _analyzeRoute() async {
    final startParts = _startController.text.trim().split(',');
    final endParts = _endController.text.trim().split(',');

    if (startParts.length != 2 || endParts.length != 2) {
      setState(() => _error = 'Enter coordinates as: lat, lon');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _routes = [];
    });

    try {
      final response = await _dio.post(
        'https://convoy-risk-analyzer-production.up.railway.app/route/plan',
        data: {
          "origin": [double.parse(startParts[0]), double.parse(startParts[1])],
          "destination": [double.parse(endParts[0]), double.parse(endParts[1])],
          "k": 3,
        },
      );
      final routes = response.data['routes'] as List;

      // Sort by safety descending (safest first)
      routes.sort(
        (a, b) => (b['safety_probability'] as num).compareTo(
          a['safety_probability'] as num,
        ),
      );

      setState(() => _routes = routes);

      // Zoom map to fit the route
      if (routes.isNotEmpty) {
        final firstPath = routes[0]['path'] as List;
        final points = firstPath
            .map<LatLng>((p) => LatLng(p[0].toDouble(), p[1].toDouble()))
            .toList();
        if (points.isNotEmpty) {
          _mapController.move(points[points.length ~/ 2], 6);
        }
      }
    } catch (e) {
      setState(() => _error = 'Failed to connect to backend: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Polyline> _buildPolylines() {
    List<Polyline> polylines = [];

    for (int i = 0; i < _routes.length; i++) {
      final segments = _routes[i]['segments'] as List?;
      if (segments == null || segments.isEmpty) continue;

      // Group consecutive segments of same color into one polyline
      List<LatLng> currentPoints = [];
      Color? currentColor;

      for (final segment in segments) {
        final risk = (segment['risk'] as num).toDouble();
        final start = segment['start'] as List;
        final end = segment['end'] as List;

        Color color = risk < 0.2
            ? Colors.green
            : risk < 0.5
            ? Colors.orange
            : Colors.red;
        if (i > 0) color = color.withOpacity(0.4);

        if (currentColor == null || color.value != currentColor.value) {
          // Flush current group
          if (currentPoints.length >= 2) {
            polylines.add(
              Polyline(
                points: currentPoints,
                strokeWidth: i == 0 ? 4.0 : 2.5,
                color: currentColor!,
              ),
            );
          }
          currentColor = color;
          currentPoints = [LatLng(start[0].toDouble(), start[1].toDouble())];
        }
        currentPoints.add(LatLng(end[0].toDouble(), end[1].toDouble()));
      }

      // Flush last group
      if (currentPoints.length >= 2) {
        polylines.add(
          Polyline(
            points: currentPoints,
            strokeWidth: i == 0 ? 4.0 : 2.5,
            color: currentColor!,
          ),
        );
      }
    }

    return polylines;
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];
    final startParts = _startController.text.trim().split(',');
    final endParts = _endController.text.trim().split(',');

    if (startParts.length == 2) {
      try {
        markers.add(
          Marker(
            point: LatLng(
              double.parse(startParts[0]),
              double.parse(startParts[1]),
            ),
            child: const Icon(Icons.location_on, color: Colors.green, size: 36),
          ),
        );
      } catch (_) {}
    }
    if (endParts.length == 2) {
      try {
        markers.add(
          Marker(
            point: LatLng(double.parse(endParts[0]), double.parse(endParts[1])),
            child: const Icon(Icons.flag, color: Colors.red, size: 36),
          ),
        );
      } catch (_) {}
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Convoy Risk Analyzer")),
      body: Stack(
        children: [
          // Layer 1: Map with polylines and markers
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(20.5937, 78.9629),
              initialZoom: 6,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png?api_key=9070a58a-cace-4eca-94ed-779f824a17ce',
                userAgentPackageName: 'com.convoy.risk',
                retinaMode: true,
              ),

              if (_routes.isNotEmpty)
                PolylineLayer(polylines: _buildPolylines()),
              if (_routes.isNotEmpty) MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Layer 2: Input Panel
          Positioned(
            top: 16,
            left: 16,
            width: 320,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _startController,
                      decoration: const InputDecoration(
                        labelText: 'Start Point',
                        hintText: 'e.g. 28.6139, 77.2090',
                        prefixIcon: Icon(
                          Icons.location_on,
                          color: Colors.green,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _endController,
                      decoration: const InputDecoration(
                        labelText: 'End Point',
                        hintText: 'e.g. 19.0760, 72.8777',
                        prefixIcon: Icon(Icons.flag, color: Colors.red),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _analyzeRoute,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.route),
                        label: Text(
                          _loading ? 'Analyzing...' : 'Analyze Route',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    if (_routes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      ..._routes.asMap().entries.map(
                        (entry) => ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                _routeColors[entry.key % _routeColors.length],
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            'Safety: ${entry.value['safety_percentage']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${entry.value['distance_km']} km  ·  ${entry.value['duration_hrs']} hrs',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
