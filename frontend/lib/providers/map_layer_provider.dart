import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapLayer {
  final String name;
  final String urlTemplate;
  final List<String>? subdomains;
  final int maxZoom;

  const MapLayer({
    required this.name,
    required this.urlTemplate,
    this.subdomains,
    this.maxZoom = 19,
  });
}

final mapLayers = {
  'Dark Mode': const MapLayer(
    name: 'Dark Mode',
    urlTemplate: 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png',
  ),
  'Standard': const MapLayer(
    name: 'Standard',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    maxZoom: 19,
  ),
  'Satellite': const MapLayer(
    name: 'Satellite',
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    maxZoom: 18,
  ),
  'Terrain': const MapLayer(
    name: 'Terrain',
    urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'],
    maxZoom: 17,
  ),
};

class LayerStateNotifier extends StateNotifier<MapLayer> {
  LayerStateNotifier() : super(mapLayers['Dark Mode']!);

  void setLayer(String layerName) {
    if (mapLayers.containsKey(layerName)) {
      state = mapLayers[layerName]!;
    }
  }
}

final layerStateProvider = StateNotifierProvider<LayerStateNotifier, MapLayer>(
  (ref) => LayerStateNotifier(),
);
