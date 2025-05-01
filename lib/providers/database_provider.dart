import 'package:flutter_riverpod/flutter_riverpod.dart'; // Core Riverpod library
import 'package:invoice_generator/data/database.dart'; // Import the AppDatabase class

// Provider for the AppDatabase instance.
// This creates a single instance of the database and makes it available
// throughout the application via Riverpod.
final databaseProvider = Provider<AppDatabase>((ref) {
  // Create the database instance.
  final db = AppDatabase();

  // Optional: Register a cleanup function to close the database when
  // the provider is disposed (e.g., when the app closes).
  ref.onDispose(() {
    print("Closing database connection."); // Log closing
    db.close();
  });

  print("Database provider initialized."); // Log initialization
  return db;
});

// FutureProvider to asynchronously check if shop information exists in the database.
// This is used by the main App widget to decide whether to show the
// setup screen or the home screen on startup.
final shopInfoProvider = FutureProvider<ShopData?>((ref) async {
  print("Checking shop info..."); // Log check
  // Watch the databaseProvider to get the AppDatabase instance.
  // Watching ensures this provider rebuilds if databaseProvider changes (though unlikely here).
  final db = ref.watch(databaseProvider);

  // Fetch all shop entries from the database.
  // In this app version, we expect at most one entry.
  final shops = await db.getAllShops();

  // If the list of shops is not empty, return the first shop entry.
  if (shops.isNotEmpty) {
    print("Shop info found."); // Log found
    return shops.first;
  } else {
    // If no shop entries are found, return null.
    print("No shop info found."); // Log not found
    return null;
  }
});
