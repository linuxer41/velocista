import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget {
  final String title;
  final bool hasBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget> actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.hasBackButton = false,
    this.onBackPressed,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colorScheme.surface,
      child: Row(
        children: [
          // Back button on the left
          if (hasBackButton)
            IconButton(
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.arrow_back,
                color: colorScheme.onSurface,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(width: 24), // Spacer to center title
          // Centered title
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Space Grotesk',
                ),
              ),
            ),
          ),
          // Action buttons on the right
          Row(
            mainAxisSize: MainAxisSize.min,
            children: actions,
          ),
        ],
      ),
    );
  }
}