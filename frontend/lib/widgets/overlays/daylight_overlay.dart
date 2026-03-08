import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class DaylightOverlay extends StatefulWidget {
  final bool isVisible;

  const DaylightOverlay({super.key, required this.isVisible});

  @override
  State<DaylightOverlay> createState() => _DaylightOverlayState();
}

class _DaylightOverlayState extends State<DaylightOverlay> {
  late Timer _timer;
  List<LatLng> _nightPolygon = [];

  @override
  void initState() {
    super.initState();
    _recalculateTerminator();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isVisible) {
        setState(() {});
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted && widget.isVisible) {
        _recalculateTerminator();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _recalculateTerminator() {
    final now = DateTime.now().toUtc();
    final points = <LatLng>[];

    // Simplified solar terminator math
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final declination = -23.44 * _cosDegrees((360.0 / 365.24) * (dayOfYear + 10));
    final equationOfTime = 9.87 * _sinDegrees(2 * (360.0 / 365.24) * (dayOfYear - 81)) 
                          - 7.53 * _cosDegrees((360.0 / 365.24) * (dayOfYear - 81)) 
                          - 1.5 * _sinDegrees((360.0 / 365.24) * (dayOfYear - 81));
    
    final solarTimeOffset = (now.hour * 60 + now.minute) + equationOfTime;
    final subSolarLon = (12 * 60 - solarTimeOffset) / 4.0; 

    // Generate 360 points for the terminator curve
    for (int lon = -180; lon <= 180; lon++) {
      final hourAngle = lon - subSolarLon;
      try {
        double latRaw = _atanDegrees(-_cosDegrees(hourAngle) / _tanDegrees(declination));
        final lat = latRaw.clamp(-90.0, 90.0);
        points.add(LatLng(lat, lon.toDouble()));
      } catch (e) {
        points.add(LatLng(0, lon.toDouble()));
      }
    }

    // Build the night side polygon (wrap around the poles depending on season)
    final polygon = List<LatLng>.from(points);
    
    // Close the polygon along the dark pole
    if (declination > 0) {
      // Northern hemisphere summer -> South pole is dark
      polygon.add(const LatLng(-90, 180));
      polygon.add(const LatLng(-90, -180));
    } else {
      // Northern hemisphere winter -> North pole is dark
      polygon.add(const LatLng(90, 180));
      polygon.add(const LatLng(90, -180));
    }
    polygon.add(points.first); // Close loop

    if (mounted) {
      setState(() {
        _nightPolygon = polygon;
      });
    }
  }

  double _sinDegrees(double degrees) => math.sin(degrees * math.pi / 180.0);
  double _cosDegrees(double degrees) => math.cos(degrees * math.pi / 180.0);
  double _tanDegrees(double degrees) => math.tan(degrees * math.pi / 180.0);
  double _atanDegrees(double ratio) => math.atan(ratio) * 180.0 / math.pi;

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible || _nightPolygon.isEmpty) return const SizedBox.shrink();

    return PolygonLayer(
      polygons: [
        Polygon(
          points: _nightPolygon,
          color: Colors.black.withValues(alpha: 0.5),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        )
      ],
    );
  }
}
