import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod for state management
import 'package:invoice_generator/app.dart';
import 'package:window_size/window_size.dart'; // Import the main App widget

void main() {
  // Ensure Flutter bindings are initialized before running the app.
  // This is often required for plugins that interact with the platform channel.
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    setWindowMinSize(const Size(800, 600)); // Set minimum width and height
    setWindowTitle('Invoice Generator');
  }

  // Run the app, wrapped in a ProviderScope.
  // ProviderScope makes Riverpod providers available throughout the widget tree.
  runApp(const ProviderScope(child: MyApp()));
}
