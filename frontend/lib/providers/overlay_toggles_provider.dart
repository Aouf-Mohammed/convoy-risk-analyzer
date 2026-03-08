import 'package:flutter_riverpod/flutter_riverpod.dart';

class OverlayToggles {
  final bool groundTraffic;
  final bool daylightCycle;
  final bool airTraffic;

  const OverlayToggles({
    this.groundTraffic = false,
    this.daylightCycle = false,
    this.airTraffic = false,
  });

  OverlayToggles copyWith({
    bool? groundTraffic,
    bool? daylightCycle,
    bool? airTraffic,
  }) {
    return OverlayToggles(
      groundTraffic: groundTraffic ?? this.groundTraffic,
      daylightCycle: daylightCycle ?? this.daylightCycle,
      airTraffic: airTraffic ?? this.airTraffic,
    );
  }
}

class OverlayTogglesNotifier extends StateNotifier<OverlayToggles> {
  OverlayTogglesNotifier() : super(const OverlayToggles());

  void toggleGroundTraffic() {
    state = state.copyWith(groundTraffic: !state.groundTraffic);
  }

  void toggleDaylightCycle() {
    state = state.copyWith(daylightCycle: !state.daylightCycle);
  }

  void toggleAirTraffic() {
    state = state.copyWith(airTraffic: !state.airTraffic);
  }
}

final overlayTogglesProvider = StateNotifierProvider<OverlayTogglesNotifier, OverlayToggles>(
  (ref) => OverlayTogglesNotifier(),
);
