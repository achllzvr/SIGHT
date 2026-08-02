import 'package:flutter/material.dart';

import '../services/gamification_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';
import '../widgets/lumi_game_kit.dart';

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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(LumiTheme.caps('Dress Up'), style: LumiTheme.joyful(22, color: LumiColors.textDark)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: LumiColors.textDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(LumiSpacing.xl),
            child: ValueListenableBuilder<int>(
              valueListenable: GamificationService.instance.coinsNotifier,
              builder: (context, coins, _) {
                return ArcadeScoreBadge(
                  arcadeIcon: 'star',
                  label: '$coins Stars',
                  accentColor: LumiColors.badgeAmber,
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(LumiSpacing.lg, 0, LumiSpacing.lg, LumiSpacing.lg),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: LumiSpacing.lg,
                mainAxisSpacing: LumiSpacing.lg,
                childAspectRatio: 0.72,
              ),
              itemCount: storeItems.length,
              itemBuilder: (context, index) {
                final item = storeItems[index];
                return _StoreItemCard(item: item);
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
    return ValueListenableBuilder<String?>(
      valueListenable: GamificationService.instance.equippedItemKeyNotifier,
      builder: (context, equipped, _) {
        final isEquipped = equipped == widget.item['key'];
        return ArcadeCard(
          padding: const EdgeInsets.all(LumiSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ArcadeIcon(widget.item['icon'] as String, size: 44),
              const SizedBox(height: LumiSpacing.md),
              Text(
                widget.item['name'] as String,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LumiTheme.clanMedium(15, color: LumiColors.textDark),
              ),
              if (widget.item['desc'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: LumiSpacing.sm),
                  child: Text(
                    widget.item['desc'] as String,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LumiTheme.clanRegular(11),
                  ),
                ),
              const SizedBox(height: LumiSpacing.sm),
              Text(
                '${widget.item['cost']} Stars',
                style: LumiTheme.clanMedium(13, color: LumiColors.primaryGreen),
              ),
              const SizedBox(height: LumiSpacing.md),
              if (_owned == true)
                LumiPressButton(
                  label: isEquipped ? 'WEARING' : 'WEAR',
                  height: 44,
                  fontSize: 13,
                  backgroundColor: isEquipped ? LumiColors.secondaryGreen : LumiColors.secondaryPurple,
                  onPressed: () async {
                    if (isEquipped) {
                      await GamificationService.instance.unequipItem();
                    } else {
                      await GamificationService.instance.equipItem(widget.item['key'] as String);
                    }
                  },
                )
              else
                LumiPressButton(
                  label: 'BUY',
                  height: 44,
                  fontSize: 13,
                  backgroundColor: LumiColors.secondaryPurple,
                  onPressed: () => _handlePurchase(context),
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough Stars!')),
      );
    }
  }
}
