import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  final String role;
  final String unitName;

  const HomeScreen({super.key, required this.role, required this.unitName});

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
  String? _liveUpdate;

  late WebSocketChannel _channel;
  final List<Color> _routeColors = [Colors.green, Colors.orange, Colors.red];

  final Map<String, int> _convoyComposition = {
    'motorcycle': 0,
    'truck': 1,
    'APC': 0,
    'tank': 0,
    'artillery': 0,
  };

  final Map<String, double> _vehicleRiskWeight = {
    'motorcycle': 0.1,
    'truck': 0.3,
    'APC': 0.5,
    'tank': 0.8,
    'artillery': 0.9,
  };

  double get _convoyRiskMultiplier {
    double total = 0;
    int count = 0;
    _convoyComposition.forEach((type, qty) {
      if (qty > 0) {
        total += (_vehicleRiskWeight[type] ?? 0.3) * qty;
        count += qty;
      }
    });
    if (count == 0) return 1.0;
    double avgWeight = total / count;
    double sizeFactor = 1.0 + (count / 20).clamp(0.0, 0.5);
    return (avgWeight * sizeFactor).clamp(0.5, 2.0);
  }

  int get _totalVehicles => _convoyComposition.values.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(
          'wss://convoy-risk-analyzer-production.up.railway.app/ws/risk-updates',
        ),
      );
      _channel.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['type'] == 'route_computed') {
            setState(() {
              _liveUpdate =
                  'Route ${data['route_id'] + 1} computed — Safety: ${data['safety']} · ${data['distance_km']} km';
            });
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _liveUpdate = null);
            });
          }
        },
        onError: (e) => debugPrint('WebSocket error: $e'),
        onDone: () => debugPrint('WebSocket closed'),
      );
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _analyzeRoute() async {
    final startParts = _startController.text.trim().split(',');
    final endParts = _endController.text.trim().split(',');

    if (startParts.length != 2 || endParts.length != 2) {
      setState(() => _error = 'Enter coordinates as: lat, lon');
      return;
    }

    if (_totalVehicles == 0) {
      setState(() => _error = 'Add at least one vehicle to the convoy');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _routes = [];
      _liveUpdate = null;
    });

    try {
      final dominantVehicle = _convoyComposition.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;

      final response = await _dio.post(
        'https://convoy-risk-analyzer-production.up.railway.app/route/plan',
        data: {
          "origin": [double.parse(startParts[0]), double.parse(startParts[1])],
          "destination": [double.parse(endParts[0]), double.parse(endParts[1])],
          "k": 3,
          "vehicle_type": dominantVehicle,
          "convoy_composition": _convoyComposition,
          "risk_multiplier": _convoyRiskMultiplier,
        },
      );

      final routes = response.data['routes'] as List;

      for (var route in routes) {
        final original = (route['safety_probability'] as num).toDouble();
        final adjusted = (original / _convoyRiskMultiplier).clamp(0.0, 1.0);
        route['safety_probability'] = adjusted;
        route['safety_percentage'] = '${(adjusted * 100).toStringAsFixed(2)}%';
      }

      routes.sort(
        (a, b) => (b['safety_probability'] as num).compareTo(
          a['safety_probability'] as num,
        ),
      );

      setState(() => _routes = routes);

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

  Widget _buildVehicleRow(String type, String label) {
    final count = _convoyComposition[type] ?? 0;
    // Only commanders can modify composition
    final canEdit = widget.role == 'commander';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: canEdit && count > 0
                    ? () => setState(() => _convoyComposition[type] = count - 1)
                    : null,
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: canEdit
                    ? () => setState(() => _convoyComposition[type] = count + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color get _roleColor => widget.role == 'commander'
      ? Colors.indigo
      : widget.role == 'analyst'
      ? Colors.teal
      : Colors.grey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Convoy Risk Analyzer"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: Chip(
              label: Text(
                '${widget.role.toUpperCase()}  ·  ${widget.unitName}',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor: _roleColor,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
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

          if (_liveUpdate != null)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    _liveUpdate!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),

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
                      // Drivers cannot type — read only
                      readOnly: widget.role == 'driver',
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
                      readOnly: widget.role == 'driver',
                      decoration: const InputDecoration(
                        labelText: 'End Point',
                        hintText: 'e.g. 19.0760, 72.8777',
                        prefixIcon: Icon(Icons.flag, color: Colors.red),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Convoy composition — visible to all, editable only by commander
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Convoy Composition',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '$_totalVehicles vehicles  |  Risk x${_convoyRiskMultiplier.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _convoyRiskMultiplier > 1.2
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildVehicleRow('motorcycle', 'Motorcycle'),
                          _buildVehicleRow('truck', 'Truck'),
                          _buildVehicleRow('APC', 'APC'),
                          _buildVehicleRow('tank', 'Tank'),
                          _buildVehicleRow('artillery', 'Artillery'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Drivers cannot analyze — they only view
                    if (widget.role != 'driver')
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

                    if (widget.role == 'driver')
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'View-only access',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
                            '${entry.value['distance_km']} km  ·  ${entry.value['duration_hrs']} hrs  ·  ${entry.value['vehicle_type'] ?? ''}',
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
