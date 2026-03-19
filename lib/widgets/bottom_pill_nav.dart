import 'package:flutter/material.dart';

class BottomPillNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  const BottomPillNav({Key? key, this.currentIndex = 0, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Center(
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.black87, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final icon = i == 0
                    ? Icons.favorite
                    : i == 1
                        ? Icons.monitor_heart
                        : Icons.list;
                final selected = i == currentIndex;
                return GestureDetector(
                  onTap: () => onTap?.call(i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: selected
                        ? BoxDecoration(
                            color: Colors.purple[100],
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Icon(icon, color: Colors.black87),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
