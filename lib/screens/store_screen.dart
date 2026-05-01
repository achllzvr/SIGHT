import 'package:flutter/material.dart';
import '../services/gamification_service.dart';
import '../widgets/rounded_card.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  // Example items for the store
  static const List<Map<String, dynamic>> storeItems = [
    {'key': 'skin_blue', 'name': 'Blue Tint', 'cost': 50, 'icon': Icons.palette},
    {'key': 'skin_pink', 'name': 'Pink Tint', 'cost': 50, 'icon': Icons.palette},
    {'key': 'acc_hat', 'name': 'Party Hat', 'cost': 100, 'icon': Icons.celebration},
  ];

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('LUMI Store', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Coin Balance Header
          Container(
            padding: const EdgeInsets.all(24),
            child: ValueListenableBuilder<int>(
              valueListenable: GamificationService.instance.coinsNotifier,
              builder: (context, coins, _) {
                return RoundedCard(
                  backgroundColor: const Color(0xFFEFD9EE),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on, color: Color(0xFF8F5A88), size: 32),
                      const SizedBox(width: 12),
                      Text(
                        '$coins COINS',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
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

class _StoreItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _StoreItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item['icon'], size: 48, color: const Color(0xFFA68AC0)),
          const SizedBox(height: 12),
          Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('${item['cost']} Coins', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _handlePurchase(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD5C2E8),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase(BuildContext context) async {
    final success = await GamificationService.instance.processWalletTransaction(
      itemKey: item['key'],
      itemName: item['name'],
      itemCost: item['cost'],
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You bought ${item['name']}!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins!')),
      );
    }
  }
}