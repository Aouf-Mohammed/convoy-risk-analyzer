import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GroundTrafficOverlay extends StatefulWidget {
  final bool isVisible;

  const GroundTrafficOverlay({super.key, required this.isVisible});

  @override
  State<GroundTrafficOverlay> createState() => _GroundTrafficOverlayState();
}

class _GroundTrafficOverlayState extends State<GroundTrafficOverlay> {
  late Timer _trafficTimer;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _trafficTimer = Timer.periodic(const Duration(seconds: 90), (timer) {
      if (mounted && widget.isVisible) {
        setState(() {
          _refreshKey++;
        });
      }
    });
  }

  @override
  void dispose() {
    _trafficTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final key = dotenv.env['TOMTOM_KEY'] ?? '';
    
    // Defer showing the snackbar so we don't do it inside build directly
    if (key.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Traffic API key missing — add TOMTOM_KEY to .env'),
              backgroundColor: Colors.red,
            )
          );
        }
      });
      return const SizedBox.shrink();
    }

    return Opacity(
      opacity: 0.65,
      child: TileLayer(
        key: ValueKey('traffic_$_refreshKey'),
        urlTemplate: 'https://api.tomtom.com/traffic/map/4/tile/flow/relative-delay/{z}/{x}/{y}.png?key=$key',
        tileProvider: CancellableNetworkTileProvider(),
        errorTileCallback: (tile, error, stackTrace) {
          debugPrint('Traffic tile error: $error');
        },
      ),
    );
  }
}
