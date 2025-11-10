import 'package:flutter/material.dart';
import '../app_state.dart';
import '../pages/home_page.dart';
import '../pages/terminal_page.dart';
import '../pages/settings_page.dart';

class WindowsLayout extends StatefulWidget {
  final AppState appState;
  final ThemeProvider themeProvider;

  const WindowsLayout({
    super.key,
    required this.appState,
    required this.themeProvider,
  });

  @override
  State<WindowsLayout> createState() => _WindowsLayoutState();
}

class _WindowsLayoutState extends State<WindowsLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      HomePage(themeProvider: widget.themeProvider),
      TerminalPage(provider: widget.appState),
      SettingsPage(
        appState: widget.appState,
        themeProvider: widget.themeProvider,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 200,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                // App title
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'BotFR',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Divider(),

                // Navigation items
                _buildSidebarItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  index: 0,
                ),
                _buildSidebarItem(
                  icon: Icons.terminal,
                  label: 'Terminal',
                  index: 1,
                ),
                _buildSidebarItem(
                  icon: Icons.settings,
                  label: 'Configuración',
                  index: 2,
                ),

                const Spacer(),

                // Connection status indicator
                ValueListenableBuilder<bool>(
                  valueListenable: widget.appState.isConnected,
                  builder: (context, isConnected, child) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            color: isConnected ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isConnected ? 'Conectado' : 'Desconectado',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}