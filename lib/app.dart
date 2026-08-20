import 'package:flutter/material.dart';

import 'features/semantic_home_page.dart';

final class DrujbaSemanticaApp extends StatelessWidget {
  const DrujbaSemanticaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF69F0AE);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: const Color(0xFF101613),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Drujba Semantică',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF060908),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101613),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        dividerColor: const Color(0xFF35413B),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF151D19),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const SemanticHomePage(),
    );
  }
}
