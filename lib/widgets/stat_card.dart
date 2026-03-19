import 'package:flutter/material.dart';
import 'rounded_card.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String? status;
  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    this.subtitle,
    this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      )),
              const SizedBox(height: 6),
              Text(value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      )),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: TextStyle(color: Colors.pink[200]))
              ]
            ],
          ),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(status!, style: TextStyle(color: Colors.green[800])),
            )
        ],
      ),
    );
  }
}
