import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_generator/providers/database_provider.dart';
import 'package:invoice_generator/screens/setup_screen.dart';
import 'package:invoice_generator/screens/main_screen.dart';

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncShop = ref.watch(shopInfoProvider);

    return MaterialApp(
      title: 'Invoice Generator',
      theme: ThemeData(
        // Define a custom color scheme
        colorScheme: const ColorScheme.light(
          primary: Colors.indigo, // Accent color
          secondary: Colors.indigoAccent, // Secondary accent
          background: Colors.white, // Background color
          surface: Colors.white, // Card and surface color
          onPrimary: Colors.white, // Text color on primary
          onSecondary: Colors.white, // Text color on secondary
          onBackground: Colors.black, // Text color on background
          onSurface: Colors.black, // Text color on surface
        ),
        scaffoldBackgroundColor: Colors.white, // Light white background
        useMaterial3: true, // Enable Material 3 design
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo, // Button color
            foregroundColor: Colors.white, // Text color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          filled: true,
          fillColor: Colors.white70, // Input field background
        ),
        cardTheme: CardTheme(
          color: Colors.white, // Card background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: asyncShop.when(
        data: (shop) {
          if (shop == null) {
            return const SetupScreen();
          } else {
            return const MainScreen();
          }
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading application data: $err'),
            ),
          ),
        ),
      ),
    );
  }
}