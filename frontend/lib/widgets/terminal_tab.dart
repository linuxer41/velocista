import 'package:flutter/material.dart';
import '../line_follower_state.dart';

class TerminalTab extends StatelessWidget {
  final LineFollowerState provider;

  const TerminalTab({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bluetooth Terminal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Toggle for raw data
                    ValueListenableBuilder<bool>(
                      valueListenable: provider.showRawData,
                      builder: (context, showRaw, child) {
                        return Switch(
                          value: showRaw,
                          onChanged: (value) {
                            provider.showRawData.value = value;
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Raw Data',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: provider.clearTerminal,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: provider.terminalMessages.length,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(8.0),
                itemBuilder: (context, index) {
                  final message = provider.terminalMessages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 2.0),
                    child: SelectableText(
                      message,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}