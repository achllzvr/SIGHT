import 'package:flutter/material.dart';

import '../services/gamification_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  static const List<Map<String, dynamic>> storeItems = [
    {'key': 'skin_blue', 'name': 'Blue Tint', 'cost': 50, 'icon': 'plus', 'desc': 'Cool blue glow for LUMI'},
    {'key': 'skin_pink', 'name': 'Pink Tint', 'cost': 50, 'icon': 'like', 'desc': 'Soft pink sparkle'},
    {'key': 'acc_hat', 'name': 'Party Hat', 'cost': 100, 'icon': 'star', 'desc': 'Celebrate good habits!'},
    {'key': 'acc_shades', 'name': 'Cool Shades', 'cost': 75, 'icon': 'play', 'desc': 'Eye-care hero look'},
    {'key': 'acc_scarf', 'name': 'Cozy Scarf', 'cost': 80, 'icon': 'tshirt', 'desc': 'Snug and stylish'},
    {'key': 'acc_crown', 'name': 'Star Crown', 'cost': 150, 'icon': 'star', 'desc': 'For streak champions'},
  ];

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
                // Tall enough for icon + copy + compact CTA without overflow.
                mainAxisExtent: 232,
              ),
              itemCount: storeItems.length,
              itemBuilder: (context, index) {
                return _StoreItemCard(item: storeItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  const _StoreItemCard({required this.item});

  @override
  State<_StoreItemCard> createState() => _StoreItemCardState();
}

class _StoreItemCardState extends State<_StoreItemCard> {
  bool? _owned;

  @override
  void initState() {
    super.initState();
    _refreshOwned();
  }

  Future<void> _refreshOwned() async {
    final owned = await GamificationService.instance.ownsItem(widget.item['key'] as String);
    if (mounted) setState(() => _owned = owned);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name'] as String;
    final desc = widget.item['desc'] as String?;
    final cost = widget.item['cost'] as int;
    final icon = widget.item['icon'] as String;
    final key = widget.item['key'] as String;

    return ValueListenableBuilder<String?>(
      valueListenable: GamificationService.instance.equippedItemKeyNotifier,
      builder: (context, equipped, _) {
        final isEquipped = equipped == key;
        final owned = _owned == true;

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
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isEquipped ? LumiColors.secondaryGreen : LumiColors.secondaryPurple,
                        borderRadius: BorderRadius.circular(LumiRadii.md),
                        border: Border.all(
                          color: isEquipped ? LumiColors.primaryGreen : LumiColors.primaryPurple,
                          width: 2,
                        ),
                      ),
                      child: ArcadeIcon(icon, size: 28),
                    ),
                    const SizedBox(height: LumiSpacing.sm),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LumiTheme.clanMedium(14, color: LumiColors.textDark, height: 1.15),
                    ),
                    if (desc != null) ...[
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          desc,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: LumiTheme.clanRegular(11, color: LumiColors.textMuted, height: 1.25),
                        ),
                      ),
                    ] else
                      const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: LumiSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ArcadeIcon('star', size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$cost',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LumiTheme.clanMedium(13, color: LumiColors.primaryGreen, height: 1.1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LumiSpacing.sm),
              _StoreActionButton(
                label: owned ? (isEquipped ? 'Wearing' : 'Wear') : 'Buy',
                accent: owned && isEquipped ? LumiColors.primaryGreen : LumiColors.primaryPurple,
                fill: owned && isEquipped ? LumiColors.secondaryGreen : LumiColors.secondaryPurple,
                onTap: () async {
                  if (owned) {
                    if (isEquipped) {
                      await GamificationService.instance.unequipItem();
                    } else {
                      await GamificationService.instance.equipItem(key);
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
      itemKey: widget.item['key'] as String,
      itemName: widget.item['name'] as String,
      itemCost: widget.item['cost'] as int,
    );

    if (!context.mounted) return;

    if (success) {
      await _refreshOwned();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You bought ${widget.item['name']}! Tap Wear to put it on.')),
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
