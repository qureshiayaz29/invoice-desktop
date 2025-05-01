import 'dart:io'; // For File operations
import 'package:drift/drift.dart'; // Core Drift library
import 'package:drift/native.dart'; // Drift implementation for native platforms (iOS, Android, Desktop)
import 'package:path_provider/path_provider.dart'; // To find the correct directory for the database file
import 'package:path/path.dart' as p; // For joining path components

// This imports the generated code file. It will show an error initially,
// but will be created after running the build_runner command.
part 'database.g.dart';

// --- Table Definitions ---

// Table to store shop information (name, address, contact, optional logo).
// Assumes a single shop for simplicity in this version.
@DataClassName('ShopData') // Customize generated data class name if needed
class Shop extends Table {
  // Primary key, auto-incrementing integer.
  IntColumn get id => integer().autoIncrement()();

  // Shop name (required).
  TextColumn get name => text()();

  // Shop address (optional).
  TextColumn get address => text().nullable()();

  // Shop contact information (phone, email, etc.) (optional).
  TextColumn get contact => text().nullable()();

  // Path to the shop logo image file (optional).
  TextColumn get logoPath => text().nullable()();
}

// Table to store individual invoices.
@DataClassName('Invoice') // Customize generated data class name
class Invoices extends Table {
  // Primary key, auto-incrementing integer.
  IntColumn get id => integer().autoIncrement()();

  // Date and time the invoice was created.
  DateTimeColumn get date => dateTime()();

  // Customer's name (optional).
  TextColumn get customerName => text().nullable()();

  // Customer's phone number (optional).
  TextColumn get customerPhone => text().nullable()();

  // Discount amount applied to the invoice (defaults to 0.0).
  RealColumn get discount => real().withDefault(const Constant(0.0))();

  // Tax amount applied to the invoice (defaults to 0.0).
  RealColumn get tax => real().withDefault(const Constant(0.0))();

  // Final total amount for the invoice after discount and tax (defaults to 0.0).
  RealColumn get total => real().withDefault(const Constant(0.0))();
// Foreign key to the Shop table (optional, for potential multi-shop support later).
// IntColumn get shopId => integer().nullable().references(Shop, #id)(); // Example if linking to Shop
}

// Table to store items belonging to a specific invoice.
@DataClassName('InvoiceItem') // Customize generated data class name
class InvoiceItems extends Table {
  // Primary key, auto-incrementing integer.
  IntColumn get id => integer().autoIncrement()();

  // Foreign key linking this item to an invoice in the Invoices table.
  // Ensures data integrity (an item must belong to an invoice).
  IntColumn get invoiceId => integer().references(Invoices, #id)();

  // Name or description of the item.
  TextColumn get name => text()();

  // Price per unit of the item.
  RealColumn get price => real()();

  // Quantity of the item.
  IntColumn get quantity => integer()();

  // Calculated total for this line item (price * quantity). Stored for efficiency.
  RealColumn get lineTotal => real()();
}

// --- Database Connection ---

// Function to configure the database connection.
LazyDatabase _openConnection() {
  // Use a LazyDatabase to open the connection only when it's first needed.
  return LazyDatabase(() async {
    // Find the appropriate directory to store the database file.
    // getApplicationDocumentsDirectory is suitable for user-specific, persistent data.
    final dbFolder = await getApplicationDocumentsDirectory();
    // Create a File object representing the database file path.
    final file = File(p.join(dbFolder.path, 'invoice_generator_db.sqlite'));
    // Use NativeDatabase for Flutter apps running on native platforms.
    return NativeDatabase(file);
  });
}

// --- Database Class Definition ---

// Define the database class using the @DriftDatabase annotation.
// List all the tables that belong to this database.
@DriftDatabase(tables: [Shop, Invoices, InvoiceItems])
class AppDatabase extends _$AppDatabase {
  // Inherits from the generated _$AppDatabase class
  // Constructor that passes the connection function to the superclass.
  AppDatabase() : super(_openConnection());

  // Define the schema version. Increment this number if you make changes
  // to your table definitions (add columns, tables, etc.) and provide
  // a migration strategy.
  @override
  int get schemaVersion => 1;

  // --- Data Access Methods (DAOs are often preferred for larger apps) ---

  // == Shop Operations ==
  Future<List<ShopData>> getAllShops() => select(shop).get();

  Future<ShopData?> getFirstShop() =>
      select(shop).getSingleOrNull(); // Helper to get the (assumed) single shop
  Future<int> insertShop(ShopCompanion s) => into(shop).insert(s);
  Future<bool> updateShop(ShopCompanion shop) {
    return update(this.shop).replace(shop);
  }

  // Add updateShop, deleteShop if needed

  // == Invoice Operations ==
  Future<int> insertInvoice(InvoicesCompanion inv) =>
      into(invoices).insert(inv);

  Future<List<Invoice>> getAllInvoices() => select(invoices).get();

  // Example: Get invoices sorted by date descending
  Future<List<Invoice>> getAllInvoicesSorted() => (select(invoices)
        ..orderBy(
            [(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
      .get();

  Future<Invoice?> getInvoiceById(int id) =>
      (select(invoices)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<bool> updateInvoice(InvoicesCompanion inv) =>
      update(invoices).replace(inv); // Returns true if successful
  Future<int> deleteInvoice(int id) =>
      (delete(invoices)..where((tbl) => tbl.id.equals(id))).go();

  // Example: Delete invoice and its items (consider transactions for safety)
  Future<void> deleteInvoiceAndItems(int invoiceId) {
    return transaction(() async {
      await (delete(invoiceItems)
            ..where((tbl) => tbl.invoiceId.equals(invoiceId)))
          .go();
      await (delete(invoices)..where((tbl) => tbl.id.equals(invoiceId))).go();
    });
  }

  // == InvoiceItem Operations ==
  Future<int> insertInvoiceItem(InvoiceItemsCompanion item) =>
      into(invoiceItems).insert(item);

  // Insert multiple items efficiently
  Future<void> insertMultipleInvoiceItems(List<InvoiceItemsCompanion> items) =>
      batch((batch) {
        batch.insertAll(invoiceItems, items);
      });

  Future<List<InvoiceItem>> getItemsForInvoice(int invoiceId) =>
      (select(invoiceItems)..where((tbl) => tbl.invoiceId.equals(invoiceId)))
          .get();

  Future<int> deleteItemsForInvoice(int invoiceId) =>
      (delete(invoiceItems)..where((tbl) => tbl.invoiceId.equals(invoiceId)))
          .go();
// Add updateItem if needed
}
