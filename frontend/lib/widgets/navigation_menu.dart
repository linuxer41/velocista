import 'package:flutter/material.dart';

class NavigationMenu extends StatelessWidget {
  final List<Map<String, dynamic>> menuItems;
  final Function(Widget) onOpenPage;

  const NavigationMenu({
    super.key,
    required this.menuItems,
    required this.onOpenPage,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: menuItems.map((item) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 1),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onOpenPage(item['page'] as Widget),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}