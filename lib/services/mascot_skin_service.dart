/// Mascot skin catalog: each skin has one image per HP state.
///
/// HP bands (locked): Healthy >=70, Decreasing 30-69, Low 1-29, Zero == 0.
enum MascotState { healthy, decreasing, low, zero }

MascotState mascotStateForHp(int hp) {
  if (hp >= 70) return MascotState.healthy;
  if (hp >= 30) return MascotState.decreasing;
  if (hp >= 1) return MascotState.low;
  return MascotState.zero;
}

class MascotSkin {
  final String key;
  final String name;
  final String description;
  final int cost;
  final bool isDefault;

  const MascotSkin({
    required this.key,
    required this.name,
    required this.description,
    required this.cost,
    this.isDefault = false,
  });

  String get _slug => key == MascotSkinCatalog.bearKey ? 'bear' : 'frog';

  String assetForState(MascotState state) =>
      'assets/mascot/skins/${_slug}_${state.name}.webp';

  String assetForHp(int hp) => assetForState(mascotStateForHp(hp));

  /// Healthy-state image used as the shop card preview.
  String get previewAsset => assetForState(MascotState.healthy);

  List<String> get allStateAssets =>
      MascotState.values.map(assetForState).toList(growable: false);
}

class MascotSkinCatalog {
  MascotSkinCatalog._();

  static const String frogKey = 'skin_frog_green';
  static const String bearKey = 'skin_bear_brown';

  static const MascotSkin frog = MascotSkin(
    key: frogKey,
    name: 'Green Frog',
    description: 'Your first LUMI buddy — always yours!',
    cost: 0,
    isDefault: true,
  );

  static const MascotSkin bear = MascotSkin(
    key: bearKey,
    name: 'Brown Bear',
    description: 'A cozy new buddy for your eyes!',
    cost: 150,
  );

  static const List<MascotSkin> all = [frog, bear];

  static MascotSkin byKey(String? key) {
    for (final skin in all) {
      if (skin.key == key) return skin;
    }
    return frog;
  }

  static bool isKnownKey(String? key) => all.any((s) => s.key == key);

  /// Asset for [skinKey] at [hp]; unknown keys fall back to the frog.
  static String assetFor({String? skinKey, required int hp}) =>
      byKey(skinKey).assetForHp(hp);
}
