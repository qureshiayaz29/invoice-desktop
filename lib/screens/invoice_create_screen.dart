import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod for state management
import 'package:drift/drift.dart'
    show Value; // For Drift's Value wrapper (nullable fields)
import 'package:invoice_generator/providers/invoice_provider.dart'; // Provider for invoice creation state
import 'package:invoice_generator/providers/database_provider.dart'; // Provider for database access & shop info
import 'package:invoice_generator/screens/invoice_history_screen.dart';
import 'package:invoice_generator/services/pdf_service.dart'; // Service for PDF generation
import 'package:invoice_generator/data/database.dart'; // Database classes (AppDatabase, Companions)

// Screen widget for creating a new invoice, using Riverpod's ConsumerWidget.
class InvoiceCreateScreen extends ConsumerWidget {
  const InvoiceCreateScreen({Key? key}) : super(key: key);

  // --- Helper Function to Save Invoice ---
  Future<void> _saveInvoice(BuildContext context, WidgetRef ref) async {
    // Read the current invoice state and notifier *once* before async operations.
    final invoiceState = ref.read(invoiceProvider);
    final invoiceCtrl = ref.read(invoiceProvider.notifier);
    final db = ref.read(databaseProvider);
    final shopInfoAsync = ref.read(shopInfoProvider); // Read shop info provider

    // --- Input Validation ---
    // 1. Check if shop info is loaded.
    final shopInfo = shopInfoAsync.value;
    if (shopInfo == null) {
      _showErrorSnackbar(context,
          'Shop information not loaded. Please restart the app or check setup.');
      return;
    }

    // 2. Check if there are valid items.
    final validItems = invoiceState.items
        .where((item) =>
            item.name.trim().isNotEmpty && item.price > 0 && item.quantity > 0)
        .toList();
    if (validItems.isEmpty) {
      _showErrorSnackbar(context,
          'Please add at least one item with a name, positive price, and positive quantity.');
      return;
    }

    // 3. Optional: Check if total is positive (might depend on business logic with discounts)
    // if (invoiceState.total <= 0) {
    //   _showErrorSnackbar(context, 'Invoice total must be positive.');
    //   return;
    // }

    // --- Proceed with Saving ---
    try {
      // 1. Insert the main Invoice record into the database.
      final newInvoiceId = await db.insertInvoice(InvoicesCompanion.insert(
        date: DateTime.now(),
        customerName: Value(invoiceState.customerName.trim().isNotEmpty
            ? invoiceState.customerName.trim()
            : null),
        customerPhone: Value(invoiceState.customerPhone.trim().isNotEmpty
            ? invoiceState.customerPhone.trim()
            : null),
        discount: Value(invoiceState.discount),
        tax: Value(invoiceState.taxPercent),
        total: Value(invoiceState.total),
        // shopId: Value(shopInfo.id), // Uncomment if shopId relation is used
      ));

      // 2. Insert the valid Invoice Items into the database.
      final itemsToInsert = validItems
          .map((item) => InvoiceItemsCompanion.insert(
                invoiceId: newInvoiceId,
                // Link item to the newly created invoice
                name: item.name.trim(),
                price: item.price,
                quantity: item.quantity,
                lineTotal: item.lineTotal,
              ))
          .toList();
      await db.insertMultipleInvoiceItems(
          itemsToInsert); // Use batch insert for efficiency

      // 3. Generate the PDF document.
      final pdfBytes = await PdfService.generateInvoicePdf(
        shopInfo: shopInfo,
        // Pass the loaded shop info
        invoiceId: newInvoiceId,
        items: validItems,
        // Pass only the valid items used for saving
        discount: invoiceState.discount,
        tax: invoiceState.taxPercent,
        customerName: invoiceState.customerName.trim(),
        customerPhone: invoiceState.customerPhone.trim(),
        invoiceDate: DateTime.now(), // Pass the creation date
      );

      // 4. Save the PDF locally and trigger the share/print dialog.
      await PdfService.savePdf(pdfBytes, PdfService.getFileNameFromId(newInvoiceId));

      // 5. Clear the form for the next invoice.
      invoiceCtrl.clear();

      // 6. Show a success message.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice saved and PDF generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Optional: Invalidate history provider if you want history screen to auto-update
        ref.invalidate(invoiceListProvider);
      }
    } catch (e, stackTrace) {
      print('Error saving invoice: $e\n$stackTrace'); // Log detailed error
      if (context.mounted) {
        _showErrorSnackbar(
            context, 'An error occurred while saving the invoice: $e');
      }
    }
  }

  // Helper to show error messages consistently
  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the invoice provider state for UI updates.
    final invoiceState = ref.watch(invoiceProvider);
    // Read the notifier to call methods like addItem, updateItem, etc.
    final invoiceCtrl = ref.read(invoiceProvider.notifier);

    // Calculate totals based on the current state.
    final subtotal = invoiceState.subTotal;
    final total = invoiceState.total;

    return GestureDetector(
      // Allow dismissing keyboard by tapping outside fields
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Invoice Items Section ---
            _buildSectionTitle(context, 'Create invoice'),
            const SizedBox(height: 8),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              // Disable inner scrolling
              shrinkWrap: true,
              itemCount: invoiceState.items.length,
              itemBuilder: (context, index) {
                // Build UI for each item line
                return _buildInvoiceItemCard(context, ref, index);
              },
            ),
            const SizedBox(height: 12),
            Align(
              // Add Item Button
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(
                  Icons.add,
                  color: Colors.white,
                ),
                label: const Text('Add Item'),
                onPressed: () => invoiceCtrl.addItem(),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).primaryColorDark, // Lighter background
                  foregroundColor: Colors.white, // Text color
                ),
              ),
            ),
            const Divider(height: 32, thickness: 1),

            // --- Adjustments & Customer Section ---
            _buildSectionTitle(context, 'Adjustments & Customer Info'),
            const SizedBox(height: 16),
            Row(
              // Discount and Tax Fields
              children: [
                //ref.watch(invoiceProvider).items[index].quantity.toString()
                Expanded(
                  child: _buildAdjustmentField(ref, 'Discount Amount',
                      ref.watch(invoiceProvider).discount, invoiceCtrl.setDiscount),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAdjustmentField(ref, 'Tax Percentage',
                      ref.watch(invoiceProvider).taxPercent, invoiceCtrl.setTaxPercent,
                      isPercentage: true),
                )
              ],
            ),
            const SizedBox(height: 16),
            _buildCustomerField(
                ref,
                'Customer Name (Optional)',
                invoiceState.customerName,
                invoiceCtrl.setCustomerName,
                TextInputType.name),
            const SizedBox(height: 10),
            _buildCustomerField(
                ref,
                'Customer Phone (Optional)',
                invoiceState.customerPhone,
                invoiceCtrl.setCustomerPhone,
                TextInputType.phone),
            const Divider(height: 32, thickness: 1),

            // --- Totals Display Section ---
            _buildTotalsDisplay(context, subtotal, invoiceState.discount,
                invoiceState.taxPercent, total),
            const SizedBox(height: 24),

            // --- Save Button ---
            ElevatedButton.icon(
              icon: const Icon(
                Icons.save_alt,
                color: Colors.white,
              ),
              label: const Text('Save Invoice & Generate PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green, // Make save button prominent
                foregroundColor: Colors.white,
              ),
              onPressed: () => _saveInvoice(context, ref),
            ),
            const SizedBox(height: 20), // Add some bottom padding
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets for Building UI Sections ---

  // Builds the title for a section.
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }

  // Builds the card UI for a single invoice item line.
  Widget _buildInvoiceItemCard(BuildContext context, WidgetRef ref, int index) {
    final item =
        ref.watch(invoiceProvider.select((state) => state.items[index]));
    final invoiceCtrl = ref.read(invoiceProvider.notifier);
    final bool canRemove =
        ref.watch(invoiceProvider.select((state) => state.items.length > 1));

    // Use TextEditingControllers for better performance and state preservation within fields
    // Note: Requires managing controller lifecycle (creation/disposal) if used in StatefulWidget
    // For simplicity here, we'll stick to onChanged with initialValue.

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextFormField(
              // Item Name
              initialValue: ref.watch(invoiceProvider).items[index].name,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey, width: 0.05)),
                  labelText: 'Item Name',
                  hintText: 'Enter item name'),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (val) => invoiceCtrl.updateItem(index, name: val),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            Row(
              // Price and Quantity
              children: [
                Expanded(
                  // Price
                  child: TextFormField(
                    initialValue:
                        ref.watch(invoiceProvider).items[index].price == 0
                            ? ''
                            : ref
                                .watch(invoiceProvider)
                                .items[index]
                                .price
                                .toStringAsFixed(2),
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey, width: 0.05)),
                        labelText: 'Price',
                        prefixText: '₹ '),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    // Allow digits and decimal point (max 2 places)
                    onChanged: (val) => invoiceCtrl.updateItem(index,
                        price: double.tryParse(val) ?? 0.0),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  // Quantity
                  child: TextFormField(
                    initialValue: ref
                        .watch(invoiceProvider)
                        .items[index]
                        .quantity
                        .toString(),
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey, width: 0.05)),
                        labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    // Allow only digits
                    onChanged: (val) => invoiceCtrl.updateItem(index,
                        quantity: int.tryParse(val) ?? 1),
                    textInputAction:
                        TextInputAction.done, // Or next if more fields follow
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              // Line Total and Delete Button
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item price: ₹${item.lineTotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (canRemove) // Only show delete if more than one item exists
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    tooltip: 'Remove Item',
                    onPressed: () => invoiceCtrl.removeItem(index),
                    padding: EdgeInsets.zero,
                    // Reduce padding around icon
                    constraints: const BoxConstraints(), // Reduce button size
                  )
                else // Maintain space even if button isn't shown
                  const SizedBox(width: 48), // Approx width of IconButton
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Builds a text field for discount or tax adjustments.
  Widget _buildAdjustmentField(WidgetRef ref, String label, double currentValue,
      Function(double) onChanged,
      {bool isPercentage = false}) {
    return TextFormField(
      initialValue: currentValue == 0 ? '' : currentValue.toStringAsFixed(2),
      decoration: InputDecoration(
        border: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 0.05)),
        labelText: label,
        suffixText: isPercentage ? '%' : '₹',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
      ],
      onChanged: (val) => onChanged(double.tryParse(val) ?? 0.0),
      textInputAction: TextInputAction.next,
    );
  }

  // Builds a text field for customer information.
  Widget _buildCustomerField(WidgetRef ref, String label, String currentValue,
      Function(String) onChanged, TextInputType keyboardType) {
    return TextFormField(
      initialValue: currentValue,
      decoration: InputDecoration(
          border: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey, width: 0.05)),
          labelText: label),
      keyboardType: keyboardType,
      textCapitalization: keyboardType == TextInputType.name
          ? TextCapitalization.words
          : TextCapitalization.none,
      onChanged: onChanged,
      textInputAction: keyboardType == TextInputType.phone
          ? TextInputAction.done
          : TextInputAction.next,
    );
  }

  // Builds the section displaying Subtotal, Discount, Tax, and Total.
  Widget _buildTotalsDisplay(BuildContext context, double subtotal,
      double discount, double taxPercent, double total) {
    final textTheme = Theme.of(context).textTheme;
    final taxAmount = (subtotal - discount) * (taxPercent / 100);

    print('Total: $total | Discount: $discount | Tax Amount: $taxAmount');
    return Column(
      children: [
        _buildTotalRow(textTheme.titleMedium, 'Subtotal:',
            '₹${subtotal.toStringAsFixed(2)}'),
        if (discount > 0)
          _buildTotalRow(textTheme.bodyMedium, 'Discount:',
              '-₹${discount.toStringAsFixed(2)}',
              color: Colors.orange[700]),
        if (taxPercent > 0)
          _buildTotalRow(
              textTheme.bodyMedium,
              'Tax (${taxPercent.toStringAsFixed(2)}%):',
              '+₹${taxAmount.toStringAsFixed(2)}',
              color: Colors.blue[700]),
        const Divider(height: 16),
        _buildTotalRow(
            textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            'Total:',
            '₹${(total).toStringAsFixed(2)}'),
      ],
    );
  }

  // Helper for individual rows in the totals display.
  Widget _buildTotalRow(TextStyle? style, String label, String value,
      {Color? color}) {
    final effectiveStyle =
        style?.copyWith(color: color) ?? TextStyle(color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: effectiveStyle),
          Text(value, style: effectiveStyle),
        ],
      ),
    );
  }
}
