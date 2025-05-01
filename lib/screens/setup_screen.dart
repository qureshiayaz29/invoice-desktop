import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod for state management
import 'package:drift/drift.dart'
    show
        Value; // Import Value class for handling nullable fields in Drift companions
import 'package:invoice_generator/data/database.dart'; // Import database definitions (Shop table, AppDatabase)
import 'package:invoice_generator/providers/database_provider.dart'; // Import database and shopInfo providers
import 'package:invoice_generator/screens/main_screen.dart'; // Import HomeScreen to navigate after setup

// StatefulWidget for the initial setup screen, using Riverpod's ConsumerStatefulWidget.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

// State class for the SetupScreen.
class _SetupScreenState extends ConsumerState<SetupScreen> {
  // GlobalKey to uniquely identify the Form widget and allow validation.
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields to manage their state.
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();

  bool _isLoading = false; // State variable to track loading state during save

  // Dispose controllers when the widget is removed from the widget tree
  // to free up resources.
  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  // Function to handle saving the shop information.
  Future<void> _saveShopInfo() async {
    // Validate the form fields. If validation fails, do nothing.
    if (_formKey.currentState!.validate()) {
      // Trigger the onSaved callbacks for each TextFormField to update controllers/variables.
      _formKey.currentState!
          .save(); // Though using controllers makes this less critical here

      setState(() => _isLoading = true); // Set loading state

      // Read the database instance from the provider. Use 'read' as it's in a callback.
      final db = ref.read(databaseProvider);

      try {
        // Insert the shop information into the database.
        // Use ShopCompanion.insert for creating a new entry.
        // Use Value() wrapper for nullable fields to explicitly handle null or provide a value.
        await db.insertShop(ShopCompanion.insert(
          name: _shopNameController.text.trim(),
          // Get trimmed text from controller
          address: Value(_addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null),
          contact: Value(_contactController.text.trim().isNotEmpty
              ? _contactController.text.trim()
              : null),
          // logoPath: Value(null), // Add logo path saving logic if implemented
        ));

        // Invalidate the shopInfoProvider. This tells Riverpod to re-fetch the
        // shop info, which will cause the MyApp widget to rebuild and navigate
        // away from the SetupScreen to the HomeScreen.
        ref.invalidate(shopInfoProvider);

        // Check if the widget is still mounted before navigating or showing SnackBars.
        // This prevents errors if the save operation completes after the widget is disposed.
        if (mounted) {
          // Navigate to the HomeScreen, replacing the SetupScreen in the navigation stack.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      } catch (e) {
        // Handle potential errors during database insertion.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving shop info: $e')),
          );
        }
      } finally {
        // Ensure loading state is turned off regardless of success or failure.
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Shop Setup'), // Screen title
        automaticallyImplyLeading: false, // Don't show back button
      ),
      body: Center(
        // Center the form vertically on the screen
        child: SingleChildScrollView(
          // Allow scrolling if content overflows (e.g., keyboard appears)
          padding: const EdgeInsets.all(24.0), // Add padding around the form
          child: Form(
            key: _formKey, // Assign the GlobalKey to the Form
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              // Center column content vertically
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // Stretch children horizontally
              children: [
                // Title text for the setup section
                Text(
                  'Enter Your Shop Details',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall, // Use appropriate text style
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24), // Spacing

                // Shop Name text field (required)
                TextFormField(
                  controller: _shopNameController,
                  decoration: const InputDecoration(
                    labelText: 'Shop Name *',
                    // Label text, '*' indicates required
                    hintText: 'e.g., My Awesome Store',
                  ),
                  // Validator function to ensure the field is not empty
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Shop Name is required';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                  // Move focus to next field on Enter/Next
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Validate as user types
                ),
                const SizedBox(height: 16), // Spacing

                // Address text field (optional)
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (Optional)',
                    hintText: 'e.g., 123 Main St, Anytown',
                  ),
                  textCapitalization: TextCapitalization.words,
                  // Capitalize words
                  maxLines: 2,
                  // Allow up to 2 lines for address
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16), // Spacing

                // Contact text field (optional)
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact (Optional)',
                    hintText: 'e.g., Phone number or Email',
                  ),
                  keyboardType: TextInputType.text,
                  // General text input
                  textInputAction: TextInputAction.done,
                  // Indicate completion
                  onFieldSubmitted: (_) => _isLoading
                      ? null
                      : _saveShopInfo(), // Save on Done action if not loading
                ),
                const SizedBox(height: 32), // Spacing before the button

                // Save button
                ElevatedButton(
                  // Disable button while loading, otherwise call _saveShopInfo on press
                  onPressed: _isLoading ? null : _saveShopInfo,
                  child: _isLoading
                      ? const SizedBox(
                          // Show progress indicator when loading
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save & Continue'), // Button text
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
