import 'package:flutter/material.dart';
import 'app_state.dart';
import 'pages/home_page.dart';
import 'pages/terminal_page.dart';
import 'pages/config_page.dart';
import 'pages/graphs_page.dart';
import 'pages/app_settings_page.dart';

void main() {
  final appState = AppState();
  final themeProvider = ThemeProvider();

  runApp(MyApp(
    appState: appState,
    themeProvider: themeProvider,
  ));
}

class MyApp extends StatefulWidget {
  final AppState appState;
  final ThemeProvider themeProvider;

  const MyApp({
    super.key,
    required this.appState,
    required this.themeProvider,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    // Define light and dark themes
    final lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    return AppInheritedWidget(
      state: widget.appState,
      child: AnimatedBuilder(
        animation: widget.themeProvider,
        builder: (context, child) => MaterialApp(
          title: 'BotFR',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: widget.themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: MainScreen(
            appState: widget.appState,
            themeProvider: widget.themeProvider,
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final AppState appState;
  final ThemeProvider themeProvider;

  const MainScreen({
    super.key,
    required this.appState,
    required this.themeProvider,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(themeProvider: widget.themeProvider),
      const ConfigPage(), // Settings goes to config page
      TerminalPage(provider: widget.appState),
      const GraphsPage(),
      AppSettingsPage(themeProvider: widget.themeProvider), // Info goes to app settings
    ];
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: _pages[_currentIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onNavTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.smart_toy),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune),
              label: 'Ajustes',
            ),
            NavigationDestination(
              icon: Icon(Icons.terminal),
              label: 'Terminal',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart),
              label: 'Gráficos',
            ),
            NavigationDestination(
              icon: Icon(Icons.info),
              label: 'Info',
            ),
          ],
        ),
      ),
    );
  }
}
