import 'package:flutter/foundation.dart';

/// Tracks whether Watch Area (Media Hub) live tracking is active.
/// Penalties and interventions run only while [active] is true.
class WatchTrackingSession {
  WatchTrackingSession._();

  static final WatchTrackingSession instance = WatchTrackingSession._();

  final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  void setActive(bool value) {
    if (active.value == value) return;
    active.value = value;
  }
}
