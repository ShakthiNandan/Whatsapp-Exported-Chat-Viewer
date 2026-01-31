import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(const MyApp());
}

// Global Theme Controller
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'WhatsApp Chat Parser',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFECE5DD),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF075E54),
              primary: const Color(0xFF075E54), // AppBar
              secondary: const Color(0xFF128C7E),
              surface: Colors.white, // Incoming bubble
              onSurface: Colors.black87, // Fix for dialog text readability
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF075E54),
              foregroundColor: Colors.white,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0B141A), // WA Dark Bg
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.dark,
              seedColor: const Color(0xFF00A884),
              primary: const Color(0xFF1F2C34), // AppBar Dark
              secondary: const Color(0xFF005C4B), // Outgoing Dark
              surface: const Color(0xFF1F2C34), // Incoming Dark
              onSurface: const Color(0xFF005C4B), // Outgoing Dark ref
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1F2C34),
              foregroundColor: Color(0xFF8696A0),
            ),
          ),
          home: const ChatScreen(),
        );
      },
    );
  }
}
