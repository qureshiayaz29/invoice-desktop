import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod for state management
import 'package:intl/intl.dart'; // For date formatting
import 'package:invoice_generator/data/database.dart'; // Database classes (AppDatabase, Invoice, InvoiceItem)
import 'package:invoice_generator/providers/database_provider.dart';
import 'package:invoice_generator/services/pdf_service.dart'; // Provider for database access

// Provider to asynchronously fetch the list of all invoices, sorted by date descending.
// FutureProvider is suitable for one-off async operations like fetching data.
final invoiceListProvider = FutureProvider<List<Invoice>>((ref) {
  // Watch the database provider to get the database instance.
  final db = ref.watch(databaseProvider);
  // Fetch invoices and sort them (newest first) directly in the query if desired,
  // or sort them after fetching as done in the build method.
  // Example with sorting in query: return db.getAllInvoicesSorted();
  return db.getAllInvoices(); // Fetch all invoices
});

// Screen widget to display the list of saved invoices, using Riverpod's ConsumerWidget.
class InvoiceHistoryScreen extends ConsumerWidget {
  const InvoiceHistoryScreen({Key? key}) : super(key: key);

  // --- Helper Function to Show Invoice Details Dialog ---
  void _showInvoiceDetailsDialog(
      BuildContext context, WidgetRef ref, Invoice invoice) async {
    // Read the database instance (use 'read' inside async callback).
    final db = ref.read(databaseProvider);
    List<InvoiceItem> items = [];
    double subtotal = 0.0;
    bool isLoading = true; // Track loading state for items

    // Show a loading indicator initially inside the dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while loading items
      builder: (BuildContext dialogContext) {
        // Use StatefulWidget for the dialog content to manage item loading state
        return StatefulBuilder(
          builder: (context, setState) {
            // Fetch items asynchronously if not already loaded
            if (isLoading) {
              db.getItemsForInvoice(invoice.id).then((fetchedItems) {
                if (!context.mounted)
                  return; // Check if dialog context is still valid
                setState(() {
                  items = fetchedItems;
                  subtotal =
                      items.fold(0.0, (sum, item) => sum + item.lineTotal);
                  isLoading = false; // Update loading state
                });
              }).catchError((error) {
                if (!context.mounted) return;
                print("Error fetching items: $error");
                setState(() {
                  isLoading = false;
                }); // Stop loading on error
                Navigator.of(dialogContext).pop(); // Close dialog on error
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("Error loading invoice items: $error"),
                      backgroundColor: Colors.red),
                );
              });
            }

            return AlertDialog(
              title: Text('Invoice #${invoice.id} Details'),
              content: SizedBox(
                width:
                    MediaQuery.of(context).size.width * 0.8, // Responsive width
                child: isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator()) // Show loading indicator
                    : SingleChildScrollView(
                        // Allow scrolling if content overflows
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                                'Date:',
                                DateFormat.yMd().add_jm().format(invoice.date
                                    .toLocal())), // Formatted date & time
                            _buildDetailRow(
                                'Customer:',
                                invoice.customerName?.isNotEmpty ?? false
                                    ? invoice.customerName!
                                    : 'N/A'),
                            _buildDetailRow(
                                'Phone:',
                                invoice.customerPhone?.isNotEmpty ?? false
                                    ? invoice.customerPhone!
                                    : 'N/A'),
                            const Divider(height: 16),
                            Text('Items:',
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            if (items.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Text('No items found.'))
                            else
                              ...items.map((item) => Padding(
                                    padding: const EdgeInsets.only(
                                        left: 8.0, bottom: 2.0),
                                    child: Text(
                                      '• ${item.name} (Qty: ${item.quantity}, Price: ₹.${item.price.toStringAsFixed(2)}) = ₹${item.lineTotal.toStringAsFixed(2)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  )),
                            const Divider(height: 16),
                            _buildDetailRow(
                                'Subtotal:', '₹${subtotal.toStringAsFixed(2)}'),
                            if (invoice.discount > 0)
                              _buildDetailRow('Discount:',
                                  '-₹${invoice.discount.toStringAsFixed(2)}'),
                            if (invoice.tax > 0)
                              _buildDetailRow('Tax:',
                                  '+₹${invoice.tax.toStringAsFixed(2)}'),
                            const SizedBox(height: 8),
                            _buildDetailRow('Total:',
                                '₹${invoice.total.toStringAsFixed(2)}',
                                isBold: true),
                          ],
                        ),
                      ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Close'),
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(), // Close dialog
                ),

                TextButton(
                    child: const Text('View Bill'),
                    onPressed: () => {_openPdf(invoice.id)}),
                // Optional: Add Edit/Delete/Reprint buttons here
                // Example Delete Button:
                // TextButton(
                //   child: const Text('Delete', style: TextStyle(color: Colors.red)),
                //   onPressed: () => _confirmAndDeleteInvoice(dialogContext, ref, invoice.id),
                // ),
              ],
            );
          },
        );
      },
    );
  }

  void _openPdf(int id) async {
    String fileName = PdfService.getFileNameFromId(id);
    String filePath = await PdfService.getFullFilePath(fileName);
    print('Open file: $filePath');
    PdfService.openFile(filePath);
  }

  // Helper widget for rows in the details dialog
  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight:
                          isBold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }

  // --- Optional: Confirm and Delete Invoice ---
  // Future<void> _confirmAndDeleteInvoice(BuildContext dialogContext, WidgetRef ref, int invoiceId) async {
  //   final confirmed = await showDialog<bool>(
  //     context: dialogContext, // Use the dialog's context
  //     builder: (BuildContext innerDialogContext) {
  //       return AlertDialog(
  //         title: const Text('Confirm Deletion'),
  //         content: const Text('Are you sure you want to delete this invoice? This action cannot be undone.'),
  //         actions: <Widget>[
  //           TextButton(
  //             child: const Text('Cancel'),
  //             onPressed: () => Navigator.of(innerDialogContext).pop(false),
  //           ),
  //           TextButton(
  //             child: const Text('Delete', style: TextStyle(color: Colors.red)),
  //             onPressed: () => Navigator.of(innerDialogContext).pop(true),
  //           ),
  //         ],
  //       );
  //     },
  //   );

  //   if (confirmed == true) {
  //     try {
  //       final db = ref.read(databaseProvider);
  //       await db.deleteInvoiceAndItems(invoiceId); // Use combined delete method
  //       Navigator.of(dialogContext).pop(); // Close the details dialog
  //       ref.invalidate(invoiceListProvider); // Refresh the history list
  //       ScaffoldMessenger.of(dialogContext).showSnackBar( // Use context that's still mounted
  //         const SnackBar(content: Text('Invoice deleted successfully'), backgroundColor: Colors.green),
  //       );
  //     } catch (e) {
  //        print("Error deleting invoice: $e");
  //        Navigator.of(dialogContext).pop(); // Close the details dialog
  //        ScaffoldMessenger.of(dialogContext).showSnackBar( // Use context that's still mounted
  //          SnackBar(content: Text('Error deleting invoice: $e'), backgroundColor: Colors.red),
  //        );
  //     }
  //   }
  // }

  // --- Build Method ---
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the invoiceListProvider to get the async state (loading, data, error).
    final invoicesAsyncValue = ref.watch(invoiceListProvider);

    // Use .when to handle the different states of the FutureProvider.
    return invoicesAsyncValue.when(
      // State: Data loaded successfully
      data: (invoices) {
        // Sort invoices locally by date (newest first) if not done in the provider query.
        final sortedInvoices = List<Invoice>.from(invoices)
          ..sort((a, b) => b.date.compareTo(a.date));

        // If there are no invoices, display a message.
        if (sortedInvoices.isEmpty) {
          return const Center(
            child: Text(
              'No invoices saved yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        // If invoices exist, display them in a ListView.
        return RefreshIndicator(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          // Add pull-to-refresh functionality
          onRefresh: () async {
            // Invalidate the provider to trigger a refetch
            ref.invalidate(invoiceListProvider);
            // Wait for the provider to rebuild (optional, depends on desired UX)
            await ref.read(invoiceListProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12.0), // Padding around the list
            itemCount: sortedInvoices.length, // Number of items in the list
            itemBuilder: (context, index) {
              // Builder function for each list item
              final inv =
                  sortedInvoices[index]; // Get the invoice data for this item
              // Format date and time for display
              final dateStr = DateFormat.yMMMd().format(inv.date.toLocal());
              final timeStr = DateFormat.jm().format(inv.date.toLocal());

              // Use a Card and ListTile for each invoice entry.
              return Card(
                shape: const RoundedRectangleBorder(),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  // Title displays Invoice ID and Total Amount
                  title: Text(
                    'Invoice #${inv.id} - ₹${inv.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // Subtitle displays Date, Time, and Customer Name
                  subtitle: Text(
                    'Date: $dateStr at $timeStr\nCustomer: ${inv.customerName?.isNotEmpty ?? false ? inv.customerName : 'N/A'}',
                  ),
                  isThreeLine: true,
                  // Allows more space for the subtitle
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        child: Text('View Bill',
                            style: TextStyle(
                                color: Theme.of(context).primaryColor)),
                        onPressed: () {
                          _openPdf(inv.id);
                        },
                      ),
                    ],
                  ),
                  // Indicate tappable
                  // Show the details dialog when the list item is tapped.
                  onTap: () => _showInvoiceDetailsDialog(context, ref, inv),
                ),
              );
            },
          ),
        );
      },
      // State: Data is loading
      loading: () => const Center(child: CircularProgressIndicator()),
      // State: An error occurred while loading data
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error loading invoice history: $error',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
