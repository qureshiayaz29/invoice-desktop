import 'dart:io'; // For File operations
import 'dart:typed_data'; // For Uint8List (byte data)
import 'package:flutter/services.dart'; // Required for rootBundle to load fonts
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart'; // To find directories for saving files
import 'package:printing/printing.dart'; // For PDF sharing and printing functionalities
import 'package:pdf/pdf.dart'; // PDF generation core classes (PdfPageFormat, etc.)
import 'package:pdf/widgets.dart' as pw; // PDF widget library (aliased to pw)
import 'package:intl/intl.dart'; // For formatting dates
import 'package:invoice_generator/data/database.dart'; // For ShopData class
import 'package:invoice_generator/providers/invoice_provider.dart'; // For InvoiceItemModel (if used directly)
import 'package:path/path.dart' as p; // Import path package for joining paths

// Service class responsible for generating and handling PDF invoices.
class PdfService {
  // --- PDF Generation Method ---
  static Future<Uint8List> generateInvoicePdf({
    required ShopData shopInfo,
    required int invoiceId,
    required List<InvoiceItemModel> items, // Use the consistent view model
    required double discount,
    required double tax,
    required String customerName,
    required String customerPhone,
    required DateTime invoiceDate,
  }) async {
    final pdf = pw.Document(); // Create a new PDF document instance

    // --- Optional: Load Custom Fonts ---
    // final fontData = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
    // final ttf = pw.Font.ttf(fontData);
    // final boldFontData = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
    // final boldTtf = pw.Font.ttf(boldFontData);
    // final theme = pw.ThemeData.withFont(base: ttf, bold: boldTtf);

    // Calculate totals needed for the PDF
    final double subtotal =
        items.fold(0.0, (sum, item) => sum + item.lineTotal);
    final double total = (subtotal - discount) + tax;

    // Add a page (or multiple pages if needed) to the PDF document.
    pdf.addPage(
      pw.MultiPage(
        // theme: theme, // Apply custom theme if fonts are loaded
        pageFormat: PdfPageFormat.a4,
        // Standard A4 page size
        orientation: pw.PageOrientation.portrait,
        // Portrait orientation
        margin: const pw.EdgeInsets.all(32),
        // Margins around the page content

        // --- Header Builder ---
        // This function builds the content that appears at the top of each page.
        header: (pw.Context context) {
          return _buildHeader(
              shopInfo, invoiceId, invoiceDate, customerName, customerPhone);
        },

        // --- Footer Builder ---
        // This function builds the content that appears at the bottom of each page.
        footer: (pw.Context context) {
          return _buildFooter(context);
        },

        // --- Body Builder (Main Content) ---
        // This function builds the main content of the invoice body.
        build: (pw.Context context) => [
          _buildItemsTable(context, items),
          // Table displaying invoice items
          pw.SizedBox(height: 20),
          // Spacing
          _buildTotalsSection(context, subtotal, discount, tax, total),
          // Optional section for notes or terms
        ],
      ),
    );

    // Save the PDF document to a byte array (Uint8List).
    return pdf.save();
  }

  // --- Helper: Build PDF Header ---
  static pw.Widget _buildHeader(ShopData shopInfo, int invoiceId,
      DateTime invoiceDate, String customerName, String customerPhone) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left side: Shop Information
            pw.Expanded(
              flex: 2, // Give more space to shop info
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                // Take minimum vertical space
                children: [
                  pw.Text(shopInfo.name,
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  if (shopInfo.address != null && shopInfo.address!.isNotEmpty)
                    pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(shopInfo.address!)),
                  if (shopInfo.contact != null && shopInfo.contact!.isNotEmpty)
                    pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text('Contact: ${shopInfo.contact!}')),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            // Right side: Invoice Details
            pw.Expanded(
              flex: 1,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text('INVOICE',
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800)),
                  pw.SizedBox(height: 8),
                  pw.Text('Invoice #: $invoiceId',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      'Date: ${DateFormat.yMd().format(invoiceDate.toLocal())}',
                      style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 25),
        // Bill To Section
        pw.Text('Bill To:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.SizedBox(height: 4),
        pw.Text(customerName.isNotEmpty ? customerName : 'N/A'),
        if (customerPhone.isNotEmpty) pw.Text(customerPhone),
        pw.Divider(height: 25, thickness: 1.5, color: PdfColors.grey400),
        // Separator line
      ],
    );
  }

  // --- Helper: Build Items Table ---
  static pw.Widget _buildItemsTable(
      pw.Context context, List<InvoiceItemModel> items) {
    const tableHeaders = [
      '#',
      'Item Description',
      'Qty',
      'Unit Price',
      'Total'
    ];

    final tableData = <List<String>>[
      for (int i = 0; i < items.length; i++)
        [
          (i + 1).toString(), // Item number
          items[i].name,
          items[i].quantity.toString(),
          '\$${items[i].price.toStringAsFixed(2)}',
          '\$${items[i].lineTotal.toStringAsFixed(2)}',
        ],
    ];

    return pw.TableHelper.fromTextArray(
      headers: tableHeaders,
      data: tableData,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      // Light border
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
      // Header background color
      cellHeight: 30,
      cellAlignments: {
        // Align content within cells
        0: pw.Alignment.centerLeft, // #
        1: pw.Alignment.centerLeft, // Description
        2: pw.Alignment.centerRight, // Qty
        3: pw.Alignment.centerRight, // Unit Price
        4: pw.Alignment.centerRight, // Total
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      // Padding within cells
      columnWidths: {
        // Define relative column widths
        0: const pw.FixedColumnWidth(25), // Fixed width for '#'
        1: const pw.FlexColumnWidth(3.5), // Flexible width for Description
        2: const pw.FixedColumnWidth(40), // Fixed width for Qty
        3: const pw.FixedColumnWidth(70), // Fixed width for Unit Price
        4: const pw.FixedColumnWidth(80), // Fixed width for Total
      },
    );
  }

  // --- Helper: Build Totals Section ---
  static pw.Widget _buildTotalsSection(pw.Context context, double subtotal,
      double discount, double tax, double total) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      // Align the totals block to the right
      child: pw.ConstrainedBox(
        constraints: const pw.BoxConstraints(maxWidth: 220),
        // Limit the width of the totals block
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          // Align text inside the block to the right
          children: [
            _buildTotalRow('Subtotal:', '\$${subtotal.toStringAsFixed(2)}'),
            if (discount > 0) // Only show discount if it's applied
              _buildTotalRow('Discount:', '-\$${discount.toStringAsFixed(2)}'),
            if (tax > 0) // Only show tax if it's applied
              _buildTotalRow('Tax:', '+\$${tax.toStringAsFixed(2)}'),
            pw.Divider(height: 10, thickness: 0.5, color: PdfColors.grey500),
            _buildTotalRow('Total:', '\$${total.toStringAsFixed(2)}',
                isBold: true, fontSize: 14),
          ],
        ),
      ),
    );
  }

  // Helper for individual rows in the totals section
  static pw.Widget _buildTotalRow(String label, String value,
      {bool isBold = false, double fontSize = 11}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  // --- Helper: Build PDF Footer ---
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 10.0),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        // Display page number
        style: pw.Theme.of(context)
            .defaultTextStyle
            .copyWith(color: PdfColors.grey, fontSize: 9),
      ),
    );
  }

  // --- PDF Saving and Sharing Method (MODIFIED) ---
  static Future<void> savePdf(Uint8List bytes, String fileName) async {
    // **1. Save a permanent copy to Documents/InvoiceGeneratorApp/Invoices**
    try {
      // Define the full path for the permanent file.
      final permanentFilePath = await getFullFilePath(fileName);
      final permanentFile = File(permanentFilePath);

      // Write the PDF bytes to the permanent file.
      await permanentFile.writeAsBytes(bytes, flush: true);
      print('PDF saved to: ${permanentFile.path}');
    } catch (e) {
      // Handle errors during permanent save.
      print('Error saving permanent PDF copy: $e');
      // Optionally show an error message to the user, but proceed to sharing anyway.
    }
  }

  static String getFileNameFromId(int invoiceId) {
    return 'invoice_$invoiceId.pdf';
  }

  static Future<String> getFullFilePath(String fileName) async {
    // Generate a unique file name for the PDF.
    // Get the user's documents directory.
    final documentsDir = await getApplicationDocumentsDirectory();
    // Define the path for the specific subfolder.
    final invoicesDirPath =
        p.join(documentsDir.path, 'InvoiceGeneratorApp', 'Invoices');
    final invoicesDir = Directory(invoicesDirPath);

    // Create the subdirectory if it doesn't exist.
    if (!await invoicesDir.exists()) {
      await invoicesDir.create(recursive: true);
      print('Created directory: ${invoicesDir.path}');
    }

    // Define the full path for the permanent file.
    final permanentFilePath = p.join(invoicesDir.path, fileName);
    return permanentFilePath;
  }

  static void openFile(String filePath) {
    OpenFilex.open(filePath).then((result) {
      if (result.type != ResultType.done) {
        print('Failed to open PDF: ${result.message}');
      }
    }).catchError((error) {
      print('Error opening PDF: $error');
    });
  }
}
