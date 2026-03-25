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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
              border: Border.all(color: Colors.black12, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final icon = i == 0
                    ? Icons.home
                    : i == 1
                        ? Icons.monitor_heart
                        : Icons.list;
                final selected = i == currentIndex;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => onTap?.call(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: selected
                          ? BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : Colors.black54),
                    ),
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
