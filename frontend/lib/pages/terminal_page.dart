import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';

enum TerminalTab { all, received, sent }

enum MessageType { sent, received, system }

class TerminalMessage {
  final String text;
  final MessageType type;

  TerminalMessage(this.text, this.type);
}

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
  TerminalTab _selectedTab = TerminalTab.all;

  bool _isPaused = false;
  List<TerminalMessage> _displayedAll = [];
  List<TerminalMessage> _displayedReceived = [];
  List<TerminalMessage> _displayedSent = [];

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and action buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: colorScheme.surface,
              child: Row(
                children: [
                  // Back button on the left
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: colorScheme.onSurface,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  // Centered title
                  Expanded(
                    child: Center(
                      child: Text(
                        'Terminal',
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
                    children: [
                      IconButton(
                        onPressed: _clearConsole,
                        icon: Icon(
                          Icons.delete,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        tooltip: 'Limpiar Consola',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _exportLog,
                        icon: Icon(
                          Icons.ios_share,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        tooltip: 'Exportar Log',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isPaused = !_isPaused;
                            if (!_isPaused) {
                              _displayedAll = List.from(widget.provider.rawDataBuffer.value);
                              _displayedReceived = List.from(widget.provider.receivedDataBuffer.value);
                              _displayedSent = List.from(widget.provider.sentCommandsBuffer.value);
                            }
                          });
                        },
                        icon: Icon(
                          _isPaused ? Icons.play_arrow : Icons.pause,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        tooltip: _isPaused ? 'Reanudar' : 'Pausar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildTabButton('Todos', TerminalTab.all),
                  const SizedBox(width: 4),
                  _buildTabButton('Recibidos', TerminalTab.received),
                  const SizedBox(width: 4),
                  _buildTabButton('Enviados', TerminalTab.sent),
                ],
              ),
            ),

            // Quick Commands
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildQuickCommandChip('LINE FOLLOW', 'set mode 0'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('REMOTE CTRL', 'set mode 1'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('CASCADE ON', 'set cascade 1'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('CASCADE OFF', 'set cascade 0'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('REALTIME ON', 'set realtime 1'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('REALTIME OFF', 'set realtime 0'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('REALTIME SNAP', 'realtime'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('TELEMETRY', 'telemetry'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('CALIBRATE', 'calibrate'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('SAVE', 'save'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('RESET', 'reset'),
                  const SizedBox(width: 8),
                  _buildQuickCommandChip('HELP', 'help'),
                ],
              ),
            ),


            // Console Output
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: _buildTerminalContent(),
              ),
            ),

            // Command Input Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
               
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _commandController,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontFamily: 'monospace',
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enviar Comando...',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontFamily: 'Space Grotesk',
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendCommand(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: widget.provider.isConnected.value ? _sendCommand : null,
                      icon: Icon(
                        Icons.send,
                        color: colorScheme.onPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, TerminalTab tab) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedTab == tab;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Space Grotesk',
            ),
          ),
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


  Widget _buildTerminalContent() {
    switch (_selectedTab) {
      case TerminalTab.all:
        return ValueListenableBuilder<List<TerminalMessage>>(
          valueListenable: widget.provider.rawDataBuffer,
          builder: (context, messages, child) {
            if (!_isPaused) {
              _displayedAll = List.from(messages);
            }
            return _buildMixedMessageList(_displayedAll);
          },
        );
      case TerminalTab.received:
        return ValueListenableBuilder<List<TerminalMessage>>(
          valueListenable: widget.provider.receivedDataBuffer,
          builder: (context, messages, child) {
            if (!_isPaused) {
              _displayedReceived = List.from(messages);
            }
            return _buildMessageList(_displayedReceived, MessageType.received);
          },
        );
      case TerminalTab.sent:
        return ValueListenableBuilder<List<TerminalMessage>>(
          valueListenable: widget.provider.sentCommandsBuffer,
          builder: (context, messages, child) {
            if (!_isPaused) {
              _displayedSent = List.from(messages);
            }
            return _buildMessageList(_displayedSent, MessageType.sent);
          },
        );
    }
  }

  Widget _buildMessageList(List<TerminalMessage> messages, MessageType messageType) {
    if (!_isPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: messages.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        return _buildLogMessage(messages[index].text, messageType);
      },
    );
  }

  Widget _buildMixedMessageList(List<TerminalMessage> messages) {
    if (!_isPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: messages.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildLogMessage(message.text, message.type);
      },
    );
  }

  Widget _buildLogMessage(String message, MessageType messageType) {
    final colorScheme = Theme.of(context).colorScheme;

    // Determine message type and color based on MessageType enum
    Color messageColor = colorScheme.onSurface;
    String category = '[SISTEMA]';

    switch (messageType) {
      case MessageType.sent:
        messageColor = colorScheme.primary;
        category = '[ENVIADO]';
        break;
      case MessageType.received:
        messageColor = Colors.green;
        category = '[RECIBIDO]';
        break;
      case MessageType.system:
        messageColor = colorScheme.onSurfaceVariant;
        category = '[SISTEMA]';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$category ',
              style: TextStyle(
                color: messageColor,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: message,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendCommand() {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    _sendQuickCommand(command);
    _commandController.clear();
  }

  Future<void> _sendQuickCommand(String command) async {
    if (!widget.provider.isConnected.value) {
      return;
    }

    // Send command as plain text
    await widget.provider.sendCommand(command);
  }

  void _clearConsole() {
    // Clear the buffers
    widget.provider.rawDataBuffer.value = [];
    widget.provider.sentCommandsBuffer.value = [];
    widget.provider.receivedDataBuffer.value = [];
  }

  void _exportLog() {
    // Export clean messages
    final cleanMessages = widget.provider.rawDataBuffer.value.map((message) {
      return message.text;
    }).join('\n');

    Clipboard.setData(ClipboardData(text: cleanMessages));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log copiado al portapapeles'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}