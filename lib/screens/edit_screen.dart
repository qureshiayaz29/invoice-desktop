import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:invoice_generator/data/database.dart';
import 'package:invoice_generator/providers/database_provider.dart';

class EditScreen extends ConsumerStatefulWidget {
  const EditScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<EditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _saveShopInfo(int shopId) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() => _isLoading = true);

      final db = ref.read(databaseProvider);

      try {
        await db.updateShop(
          ShopCompanion(
            id: Value(shopId),
            name: Value(_shopNameController.text.trim()),
            address: Value(_addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : null),
            contact: Value(_contactController.text.trim().isNotEmpty
                ? _contactController.text.trim()
                : null),
          ),
        );

        ref.invalidate(shopInfoProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shop information updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating shop info: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopInfoAsyncValue = ref.watch(shopInfoProvider);

    return Scaffold(
      body: shopInfoAsyncValue.when(
        data: (shop) {
          if (shop == null) {
            return const Center(
              child: Text('No shop data available to edit.'),
            );
          }

          _shopNameController.text = shop.name;
          _addressController.text = shop.address ?? '';
          _contactController.text = shop.contact ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit shop details',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(
                        labelText: 'Shop Name *',
                        hintText: 'e.g., My Awesome Store',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Shop Name is required';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address (Optional)',
                        hintText: 'e.g., 123 Main St, Anytown',
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLines: 2,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactController,
                      decoration: const InputDecoration(
                        labelText: 'Contact (Optional)',
                        hintText: 'e.g., Phone number or Email',
                      ),
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) =>
                          _isLoading ? null : _saveShopInfo(shop.id),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _saveShopInfo(shop.id),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error loading shop data: $error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
