import 'package:flutter_riverpod/flutter_riverpod.dart'; // Core Riverpod library

// --- Data Models for Invoice Creation State ---

// Model representing a single line item within the invoice being created.
// This is a simple data class, not directly tied to the database schema class.
class InvoiceItemModel {
  String name;
  double price;
  int quantity;

  InvoiceItemModel({
    this.name = '', // Default empty name
    this.price = 0.0, // Default price 0
    this.quantity = 1, // Default quantity 1
  });

  // Calculated property for the total cost of this line item.
  double get lineTotal => price * quantity;

  // Helper method to create a copy with potential modifications (immutable pattern)
  InvoiceItemModel copyWith({String? name, double? price, int? quantity}) {
    return InvoiceItemModel(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }
}

// Model representing the overall state of the invoice currently being created or edited.
// This class holds all the temporary data before it's saved to the database.
class InvoiceState {
  final List<InvoiceItemModel> items; // List of line items
  final double discount; // Discount amount (assumed fixed amount)
  final double taxPercent; // Tax amount (assumed fixed amount)
  final String customerName; // Optional customer name
  final String customerPhone; // Optional customer phone

  InvoiceState({
    required this.items,
    this.discount = 0.0, // Default discount 0
    this.taxPercent = 0.0, // Default tax 0
    this.customerName = '', // Default empty customer name
    this.customerPhone = '', // Default empty customer phone
  });

  // Calculated property for the sum of all line item totals (before discount/tax).
  double get subTotal => items.fold(0.0, (sum, item) => sum + item.lineTotal);

  // Calculated property for the final total amount.
  // Assumes discount and tax are fixed amounts. Adjust if they represent percentages.
  double get total {
    final finalTotal = (subTotal - discount);
    return taxPercent > 0
        ? finalTotal + (finalTotal * taxPercent / 100)
        : finalTotal;
  }

  // Helper method to create a copy of the state with modifications (immutable pattern).
  // This is crucial for Riverpod's state management to detect changes.
  InvoiceState copyWith({
    List<InvoiceItemModel>? items,
    double? discount,
    double? taxPercent,
    String? customerName,
    String? customerPhone,
  }) {
    return InvoiceState(
      items: items ?? this.items,
      discount: discount ?? this.discount,
      taxPercent: taxPercent ?? this.taxPercent,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }
}

// --- State Notifier ---

// Manages the InvoiceState, providing methods to modify it.
// StateNotifier is suitable for managing complex state objects.
class InvoiceNotifier extends StateNotifier<InvoiceState> {
  // Initialize the state with one empty item line.
  InvoiceNotifier() : super(InvoiceState(items: [InvoiceItemModel()]));

  // Adds a new, empty item line to the invoice.
  void addItem() {
    // Create a new list containing all existing items plus a new default item.
    final updatedItems = [...state.items, InvoiceItemModel()];
    // Update the state using copyWith to ensure immutability.
    state = state.copyWith(items: updatedItems);
  }

  // Updates the details of an item at a specific index.
  void updateItem(int index, {String? name, double? price, int? quantity}) {
    // Basic bounds check to prevent errors.
    if (index < 0 || index >= state.items.length) return;

    // Create a mutable copy of the items list.
    final updatedItems = List<InvoiceItemModel>.from(state.items);
    // Get the item to update.
    final itemToUpdate = updatedItems[index];
    // Create a *new* InvoiceItemModel instance with updated values.
    updatedItems[index] = itemToUpdate.copyWith(
      name: name,
      price: price,
      quantity: quantity,
    );
    // Update the state with the modified items list.
    state = state.copyWith(items: updatedItems);
  }

  // Removes an item from the invoice at a specific index.
  void removeItem(int index) {
    // Basic bounds check.
    if (index < 0 || index >= state.items.length) return;

    // Create a mutable copy and remove the item.
    final updatedItems = List<InvoiceItemModel>.from(state.items)
      ..removeAt(index);

    // Ensure there's always at least one item line in the UI.
    // If the list becomes empty after removal, add a new default item.
    if (updatedItems.isEmpty) {
      updatedItems.add(InvoiceItemModel());
    }
    // Update the state.
    state = state.copyWith(items: updatedItems);
  }

  // Updates the discount amount.
  void setDiscount(double disc) {
    state = state.copyWith(discount: disc);
  }

  // Updates the tax amount.
  void setTaxPercent(double newTaxPercent) {
    state = state.copyWith(taxPercent: newTaxPercent);
  }

  // Updates the customer name.
  void setCustomerName(String name) {
    state = state.copyWith(customerName: name);
  }

  // Updates the customer phone number.
  void setCustomerPhone(String phone) {
    state = state.copyWith(customerPhone: phone);
  }

  // Resets the invoice form to its initial state (one empty item, zero totals).
  void clear() {
    state = InvoiceState(
        items: [InvoiceItemModel()],
        discount: 0.0,
        taxPercent: 0.0,
        customerName: '',
        customerPhone: '');
  }
}

// --- Provider Definition ---

// StateNotifierProvider that creates and exposes the InvoiceNotifier.
// Widgets can watch or read this provider to access the InvoiceState
// and the methods of InvoiceNotifier.
final invoiceProvider =
    StateNotifierProvider<InvoiceNotifier, InvoiceState>((ref) {
  return InvoiceNotifier();
});
