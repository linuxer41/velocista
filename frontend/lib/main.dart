import 'package:flutter/material.dart';
import 'app_state.dart';
import 'pages/home_page.dart';
import 'pages/terminal_page.dart';
import 'pages/settings_page.dart';

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
      child: MaterialApp(
        title: 'BotFR',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: widget.themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        initialRoute: '/',
        routes: {
          '/': (context) => HomePage(themeProvider: widget.themeProvider),
          '/terminal': (context) => TerminalPage(provider: widget.appState),
          '/settings': (context) => SettingsPage(
            appState: widget.appState,
            themeProvider: widget.themeProvider,
          ),
        },
      ),
    );
  }
}
