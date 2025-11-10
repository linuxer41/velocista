import 'dart:convert';
import 'package:flutter/material.dart';
import '../app_state.dart';

class TerminalPage extends StatefulWidget {
  final AppState provider;

  const TerminalPage({
    super.key,
    required this.provider,
  });

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _sentScrollController = ScrollController();
  final ScrollController _receivedScrollController = ScrollController();
  int _selectedTerminalTab = 0; // 0 = All, 1 = Sent, 2 = Received

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _sentScrollController.dispose();
    _receivedScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          // Connection status indicator
          ValueListenableBuilder<bool>(
            valueListenable: widget.provider.isConnected,
            builder: (context, isConnected, child) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isConnected
                      ? colorScheme.primaryContainer
                      : colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      size: 16,
                      color: isConnected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isConnected ? 'Conectado' : 'Desconectado',
                      style: TextStyle(
                        fontSize: 12,
                        color: isConnected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Compact command input section
            Container(
              margin: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commandController,
                      decoration: InputDecoration(
                        hintText: 'Ej: {"mode":1} o {"servoDistance":25}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      onSubmitted: (_) => _sendCommand(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: widget.provider.isConnected.value
                        ? _sendCommand
                        : null,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Enviar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Quick commands in a single horizontal scrollable row (original style)
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildQuickCommandChip('LINE_FOLLOW', '{"mode":0}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('CONTROL REMOTO', '{"mode":1}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('SERVO_DIST', '{"mode":2}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('POINT_LIST', '{"mode":3}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Servo 25cm', '{"servoDistance":25}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Servo 50cm', '{"servoDistance":50}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Ruta Simple', '{"routePoints":"20,0,10,-90,20,0"}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Telemetry ON', '{"telemetry_enable":true}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Telemetry OFF', '{"telemetry_enable":false}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Get Telemetry', '{"telemetry":1}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Save EEPROM', '{"eeprom":1}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Calibrate QTR', '{"calibrate_qtr":1}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('PID Config', '{"pid":[1.2,0.05,0.02]}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Speed Base', '{"speed":{"base":0.7}}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Remote Dir+Acc', '{"remote_control":{"direction":90,"acceleration":0.5}}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Remote Auto', '{"remote_control":{"throttle":0.5,"turn":-0.3}}'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('Remote Manual', '{"remote_control":{"left":0.8,"right":-0.8}}'),
                ],
              ),
            ),

            // Terminal tabs - more compact
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildTerminalTabButton('Todo', 0),
                  const SizedBox(width: 4),
                  _buildTerminalTabButton('Enviados', 1),
                  const SizedBox(width: 4),
                  _buildTerminalTabButton('Recibidos', 2),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Terminal content
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.1),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildTerminalContent(),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCommandChip(String label, String command) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: widget.provider.isConnected.value
          ? () => _sendQuickCommand(command)
          : null,
      backgroundColor: widget.provider.isConnected.value
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest.withOpacity(0.3),
      labelStyle: TextStyle(
        color: widget.provider.isConnected.value
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface.withOpacity(0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildQuickCommandButton(String label, String command, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = widget.provider.isConnected.value;

    return ElevatedButton(
      onPressed: isEnabled ? () => _sendQuickCommand(command) : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        backgroundColor: isEnabled
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerHighest.withOpacity(0.3),
        foregroundColor: isEnabled
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurface.withOpacity(0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _sendCommand() {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    _sendQuickCommand(command);
    _commandController.clear();
  }

  Widget _buildTerminalTabButton(String label, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedTerminalTab == index;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => setState(() => _selectedTerminalTab = index),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? colorScheme.primary : colorScheme.surface,
          foregroundColor: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          elevation: isSelected ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildTerminalContent() {
    switch (_selectedTerminalTab) {
      case 0: // All
        return ValueListenableBuilder<List<String>>(
          valueListenable: widget.provider.rawDataBuffer,
          builder: (context, messages, child) => _buildMessageList(messages, _scrollController),
        );
      case 1: // Sent
        return ValueListenableBuilder<List<String>>(
          valueListenable: widget.provider.sentCommandsBuffer,
          builder: (context, messages, child) => _buildMessageList(messages, _sentScrollController),
        );
      case 2: // Received
        return ValueListenableBuilder<List<String>>(
          valueListenable: widget.provider.receivedDataBuffer,
          builder: (context, messages, child) => _buildMessageList(messages, _receivedScrollController),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMessageList(List<String> messages, ScrollController controller) {
    // Auto-scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: controller,
      itemCount: messages.length,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(8.0),
      itemBuilder: (context, index) {
        final message = messages[index];
        // Limit the number of messages displayed to prevent UI overload
        final maxDisplayMessages = 500;
        if (messages.length > maxDisplayMessages &&
            index < messages.length - maxDisplayMessages) {
          return const SizedBox.shrink(); // Skip older messages
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          child: SelectableText(
            message,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendQuickCommand(String command) async {
    if (!widget.provider.isConnected.value) {
      return;
    }

    try {
      // Parse JSON command
      final Map<String, dynamic> parsedCommand;
      if (command.startsWith('{')) {
        // It's a JSON string, parse it
        parsedCommand = Map<String, dynamic>.from(
            command.contains('"') ? jsonDecode(command) : {'raw': command});
      } else {
        // It's a raw string, wrap it
        parsedCommand = {'raw': command};
      }

      await widget.provider.sendCommand(parsedCommand);
    } catch (e) {
      // Error de formato JSON - silently fail
    }
  }
}