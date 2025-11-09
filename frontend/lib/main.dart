import 'package:flutter/material.dart';
import 'app_state.dart';
import 'home.dart';
import 'theme_provider.dart';

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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen for theme changes
    widget.themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {}); // Force rebuild when theme changes
  }

  @override
  Widget build(BuildContext context) {
    return AppInheritedWidget(
      state: widget.appState,
      child: MaterialApp(
        title: 'Seguidor de Línea Bluetooth',
        debugShowCheckedModeBanner: false,
        theme: widget.themeProvider.isDarkMode
            ? _buildDarkTheme()
            : _buildLightTheme(),
        home: Home(themeProvider: widget.themeProvider),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const Color primaryColor = Color(0xFF2E7D32);
    const Color secondaryColor = Color(0xFF757575);
    const Color surface = Color(0xFFFFFFFF);
    const Color background = Color(0xFFF5F5F5);

    return ThemeData.light().copyWith(
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: Colors.black87,
        error: Color(0xFFD32F2F),
        onError: Colors.white,
        surfaceContainerHighest: Color(0xFFF5F5F5),
        onSurfaceVariant: Colors.black54,
        outline: Colors.grey,
        primaryContainer: Color(0xFFE8F5E8),
        onPrimaryContainer: Color(0xFF1B5E20),
        secondaryContainer: Color(0xFFEFEBE9),
        onSecondaryContainer: Color(0xFF3E2723),
        errorContainer: Color(0xFFFFEBEE),
        onErrorContainer: Color(0xFFC62828),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Colors.black87,
        shadowColor: Colors.black12,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: Colors.black12,
        surfaceTintColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          shadowColor: Colors.black12,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Colors.black54,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        selectedIconTheme: IconThemeData(size: 24),
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedItemColor: Colors.black54,
        unselectedIconTheme: IconThemeData(size: 24),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        backgroundColor: Color(0xFFFFFFFF),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: Colors.grey,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade300,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: Colors.grey,
        thumbColor: primaryColor,
        overlayColor: primaryColor,
        valueIndicatorColor: primaryColor,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
        trackHeight: 4,
        valueIndicatorTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        shadowColor: Colors.black12,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: Colors.black54,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.black87,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        actionTextColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade100,
        selectedColor: primaryColor.withOpacity(0.2),
        secondarySelectedColor: primaryColor.withOpacity(0.2),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const Color primaryColor = Color(0xFF4CAF50);
    const Color secondaryColor = Color(0xFF9E9E9E);
    const Color surface = Color(0xFF1E1E1E);
    const Color background = Color(0xFF121212);

    return ThemeData.dark().copyWith(
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.black,
        surface: surface,
        onSurface: Colors.white,
        error: Color(0xFFCF6679),
        onError: Colors.black,
        surfaceContainerHighest: Color(0xFF2C2C2C),
        onSurfaceVariant: Colors.white70,
        outline: Colors.grey,
        primaryContainer: Color(0xFF2E7D32),
        onPrimaryContainer: Colors.white,
        secondaryContainer: Color(0xFF424242),
        onSecondaryContainer: Colors.white,
        errorContainer: Color(0xFF8A1C1C),
        onErrorContainer: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: surface,
        foregroundColor: Colors.white,
        shadowColor: Colors.black38,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black38,
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shadowColor: Colors.black38,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Colors.white70,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        selectedIconTheme: IconThemeData(size: 24),
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedItemColor: Colors.white70,
        unselectedIconTheme: IconThemeData(size: 24),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        backgroundColor: Color(0xFF1E1E1E),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade600, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCF6679), width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: Colors.grey,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade600,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: Colors.grey,
        thumbColor: primaryColor,
        overlayColor: primaryColor,
        valueIndicatorColor: primaryColor,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
        trackHeight: 4,
        valueIndicatorTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        shadowColor: Colors.black38,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey.shade800,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        actionTextColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2C2C2C),
        selectedColor: primaryColor.withOpacity(0.2),
        secondarySelectedColor: primaryColor.withOpacity(0.2),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
