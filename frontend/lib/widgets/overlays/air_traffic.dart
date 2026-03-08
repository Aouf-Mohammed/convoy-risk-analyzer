import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/opensky_service.dart';

class AirTrafficOverlay extends StatefulWidget {
  final bool isVisible;
  final MapController mapController;

  const AirTrafficOverlay({
    super.key, 
    required this.isVisible,
    required this.mapController,
  });

  @override
  State<AirTrafficOverlay> createState() => _AirTrafficOverlayState();
}

class _AirTrafficOverlayState extends State<AirTrafficOverlay> {
  late Timer _timer;
  List<Marker> _markers = [];
  bool _isFetching = false;
  final OpenSkyService _api = OpenSkyService();

  @override
  void initState() {
    super.initState();
    _startTimer();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isVisible) {
        _fetchAirTraffic();
      }
    });

    // Listen to map changes to fetch on move end if visible
    widget.mapController.mapEventStream.listen((event) {
      if (event is MapEventMoveEnd && widget.isVisible) {
        _fetchAirTraffic();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && widget.isVisible) {
        _fetchAirTraffic();
      }
    });
  }

  Future<void> _fetchAirTraffic() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final bounds = widget.mapController.camera.visibleBounds;
      final aircraft = await _api.fetchAircraft(bounds);
      
      if (mounted) {
        setState(() {
          _markers = aircraft.map((a) => Marker(
            point: LatLng(a['lat'] as double, a['lon'] as double),
            width: 30,
            height: 30,
            child: Transform.rotate(
              angle: (a['heading'] as double) * 3.14159 / 180.0,
              child: const Icon(
                Icons.flight,
                color: Colors.cyanAccent,
                size: 20,
              ),
            ),
          )).toList();
        });
      }
    } catch (e) {
      debugPrint("Air traffic fetch error: $e");
    } finally {
      if (mounted) {
        _isFetching = false;
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible || _markers.isEmpty) return const SizedBox.shrink();

    return MarkerLayer(
      markers: _markers,
    );
  }
}
