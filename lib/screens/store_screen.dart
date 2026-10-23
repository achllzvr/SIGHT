import 'package:flutter/material.dart';

import '../services/active_child_context_service.dart';
import '../services/gamification_service.dart';
import '../services/mascot_skin_service.dart';
import '../services/server_sync_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';
import '../widgets/looping_asset_image.dart';

/// Star Shop: mascot skins only.
/// Green Frog is the free default; Brown Bear costs 150 Stars.
/// Purchases are recorded on the child's account (server inventory) with the
/// local SQLite inventory as offline cache.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  static const List<MascotSkin> storeItems = MascotSkinCatalog.all;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int _syncGen = 0;

  @override
  void initState() {
    super.initState();
    _syncInventory();
  }

  Future<void> _syncInventory() async {
    final childId = await ActiveChildContextService.instance.getActiveChildId();
    if (childId != null) {
      await ServerSyncService.instance.syncInventoryForChild(childId);
    }
    // Bump the generation so cards re-check ownership after a server restore.
    if (mounted) setState(() => _syncGen++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumiColors.scaffoldMint,
      appBar: AppBar(
        title: Text(
          LumiTheme.caps('Dress Up'),
          style: LumiTheme.joyful(22, color: LumiColors.primaryPurple),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: LumiColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(LumiSpacing.lg, 0, LumiSpacing.lg, LumiSpacing.md),
            child: ValueListenableBuilder<int>(
              valueListenable: GamificationService.instance.coinsNotifier,
              builder: (context, coins, _) {
                return Center(
                  child: ArcadeScoreBadge(
                    arcadeIcon: 'star',
                    label: '$coins',
                    accentColor: LumiColors.badgeAmber,
                    compact: true,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                LumiSpacing.lg,
                0,
                LumiSpacing.lg,
                LumiSpacing.xl,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: LumiSpacing.md,
                mainAxisSpacing: LumiSpacing.md,
                // Tall enough for skin preview + state strip + copy + CTA.
                mainAxisExtent: 318,
              ),
              itemCount: StoreScreen.storeItems.length,
              itemBuilder: (context, index) {
                final skin = StoreScreen.storeItems[index];
                return _SkinCard(key: ValueKey('${skin.key}-$_syncGen'), skin: skin);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinCard extends StatefulWidget {
  final MascotSkin skin;
  const _SkinCard({super.key, required this.skin});

  @override
  State<_SkinCard> createState() => _SkinCardState();
}

class _SkinCardState extends State<_SkinCard> {
  bool? _owned;

  @override
  void initState() {
    super.initState();
    _refreshOwned();
  }

  Future<void> _refreshOwned() async {
    final owned = await GamificationService.instance.ownsItem(widget.skin.key);
    if (mounted) setState(() => _owned = owned);
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;

    return ValueListenableBuilder<String>(
      valueListenable: GamificationService.instance.equippedItemKeyNotifier,
      builder: (context, equipped, _) {
        final isEquipped = equipped == skin.key;
        final owned = skin.isDefault || _owned == true;

        return ArcadeCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isEquipped ? LumiColors.secondaryGreen : LumiColors.secondaryPurple,
                        borderRadius: BorderRadius.circular(LumiRadii.md),
                        border: Border.all(
                          color: isEquipped ? LumiColors.primaryGreen : LumiColors.primaryPurple,
                          width: 2,
                        ),
                      ),
                      child: LoopingAssetImage(asset: skin.previewAsset, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 6),
                    // State strip: first frame only (full loops are for the hero).
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final asset in skin.allStateAssets)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Image.asset(asset, width: 26, height: 26, fit: BoxFit.contain),
                          ),
                      ],
                    ),
                    const SizedBox(height: LumiSpacing.sm),
                    Text(
                      skin.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LumiTheme.clanMedium(14, color: LumiColors.textDark, height: 1.15),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        skin.isDefault ? 'Owned · Default\n${skin.description}' : skin.description,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: LumiTheme.clanRegular(11, color: LumiColors.textMuted, height: 1.25),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LumiSpacing.sm),
              if (!owned)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ArcadeIcon('star', size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${skin.cost}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LumiTheme.clanMedium(13, color: LumiColors.primaryGreen, height: 1.1),
                    ),
                  ],
                )
              else
                Text(
                  skin.isDefault ? 'FREE' : 'OWNED',
                  textAlign: TextAlign.center,
                  style: LumiTheme.clanMedium(11, color: LumiColors.textMuted, height: 1.1),
                ),
              const SizedBox(height: LumiSpacing.sm),
              _StoreActionButton(
                label: owned ? (isEquipped ? 'Wearing' : 'Wear') : 'Buy',
                accent: owned && isEquipped ? LumiColors.primaryGreen : LumiColors.primaryPurple,
                fill: owned && isEquipped ? LumiColors.secondaryGreen : LumiColors.secondaryPurple,
                onTap: () async {
                  if (owned) {
                    if (!isEquipped) {
                      await GamificationService.instance.equipItem(skin.key);
                    }
                  } else {
                    await _handlePurchase(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePurchase(BuildContext context) async {
    final success = await GamificationService.instance.processWalletTransaction(
      itemKey: widget.skin.key,
      itemName: widget.skin.name,
      itemCost: widget.skin.cost,
    );

    if (!context.mounted) return;

    if (success) {
      await _refreshOwned();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You bought ${widget.skin.name}! LUMI is wearing it now.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough Stars!')),
      );
    }
  }
}

/// Compact arcade CTA sized for 2-column store cards.
class _StoreActionButton extends StatefulWidget {
  final String label;
  final Color accent;
  final Color fill;
  final VoidCallback onTap;

  const _StoreActionButton({
    required this.label,
    required this.accent,
    required this.fill,
    required this.onTap,
  });

  @override
  State<_StoreActionButton> createState() => _StoreActionButtonState();
}

class _StoreActionButtonState extends State<_StoreActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedSlide(
        offset: _pressed ? const Offset(0, 0.05) : Offset.zero,
        duration: LumiMotion.fast,
        child: AnimatedContainer(
          duration: LumiMotion.fast,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.fill,
            borderRadius: BorderRadius.circular(LumiRadii.pill),
            border: Border.all(color: widget.accent, width: 2.5),
            boxShadow: _pressed
                ? const []
                : [
                    BoxShadow(
                      color: widget.accent,
                      offset: const Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Text(
            LumiTheme.caps(widget.label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LumiTheme.clanMedium(12, color: widget.accent, letterSpacing: 0.8),
          ),
        ),
      ),
    );
  }
}
