import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/services/api_config_service.dart';
import 'package:lumi/services/mascot_skin_service.dart';

void main() {
  group('Mascot HP state bands', () {
    test('boundaries: Healthy >=70, Decreasing 30-69, Low 1-29, Zero == 0', () {
      expect(mascotStateForHp(100), MascotState.healthy);
      expect(mascotStateForHp(70), MascotState.healthy);
      expect(mascotStateForHp(69), MascotState.decreasing);
      expect(mascotStateForHp(30), MascotState.decreasing);
      expect(mascotStateForHp(29), MascotState.low);
      expect(mascotStateForHp(1), MascotState.low);
      expect(mascotStateForHp(0), MascotState.zero);
    });

    test('assets resolve per skin and state', () {
      expect(MascotSkinCatalog.assetFor(skinKey: MascotSkinCatalog.frogKey, hp: 80),
          'assets/mascot/skins/frog_healthy.webp');
      expect(MascotSkinCatalog.assetFor(skinKey: MascotSkinCatalog.frogKey, hp: 50),
          'assets/mascot/skins/frog_decreasing.webp');
      expect(MascotSkinCatalog.assetFor(skinKey: MascotSkinCatalog.bearKey, hp: 10),
          'assets/mascot/skins/bear_low.webp');
      expect(MascotSkinCatalog.assetFor(skinKey: MascotSkinCatalog.bearKey, hp: 0),
          'assets/mascot/skins/bear_zero.webp');
    });

    test('unknown skin falls back to frog', () {
      expect(MascotSkinCatalog.assetFor(skinKey: 'skin_rainbow', hp: 80),
          'assets/mascot/skins/frog_healthy.webp');
      expect(MascotSkinCatalog.byKey(null).key, MascotSkinCatalog.frogKey);
    });
  });

  group('Catalog', () {
    test('frog is free default, bear costs 150', () {
      expect(MascotSkinCatalog.frog.isDefault, isTrue);
      expect(MascotSkinCatalog.frog.cost, 0);
      expect(MascotSkinCatalog.bear.cost, 150);
      expect(MascotSkinCatalog.all.length, 2);
    });

    test('inventory endpoints are child-scoped', () {
      expect(ApiConfigService.inventoryEndpoint(5), '/api/mobile/child/5/inventory');
      expect(ApiConfigService.inventoryPurchaseEndpoint(5), '/api/mobile/child/5/inventory/purchase');
      expect(ApiConfigService.inventoryEquipEndpoint(5), '/api/mobile/child/5/inventory/equip');
    });
  });
}
