# Invoice Generator (Flutter Desktop + Android)

A fully offline, cross-platform **Invoice Generator App** built with **Flutter**, targeting **Windows Desktop and Android**. This app is designed for store owners to quickly generate, edit, and manage invoices with support for tax, discounts, and customer information. Invoices are saved locally and can be exported as printable PDFs.

## ✨ Features

- 🛠 **Initial Shop Setup**
    - Enter shop name, logo, address, and contact details once
    - Logo appears on invoices (centered)

- 🧾 **Invoice Creation**
    - Add items dynamically with name, price, quantity
    - Automatic line totals and grand total
    - Optional tax and discount handling
    - Optional customer name and phone number
    - PDF generated **once** per invoice and saved

- 🗂 **Invoice History**
    - View all invoices by date, customer, or invoice number
    - Edit existing invoices
    - View saved PDF directly from invoice list

- 📄 **PDF Export & Print**
    - Generates a clean invoice PDF with shop logo and invoice details
    - Saves PDF locally and stores file path in the database
    - Supports sharing or printing

- 📦 **Fully Offline**
    - No internet required
    - Uses local SQLite database via Drift

## 🧰 Tech Stack

- **Flutter** (Windows & Android)
- **Riverpod** for state management
- **Drift** (SQLite) for offline local database
- **PDF + Printing** package for invoice export
- **Material Design 3** with light theme and responsive layout

## 📁 Project Structure

```
lib/
├── main.dart
├── app.dart
├── data/                 # Drift database and tables
│   └── database.dart
├── models/               # Data models (InvoiceItem, etc.)
├── providers/            # Riverpod providers
├── screens/              # UI screens
├── services/             # PDF generation, DB helpers
└── assets/images/        # Shop logo and images
```

## 🖥 Supported Platforms

- ✅ Windows Desktop (main target)
- ✅ Android
- ✅ Fully responsive layout

## 🚀 Getting Started

```bash
flutter pub get
flutter pub run build_runner build
flutter run -d windows   # or android
```

> Ensure desktop support is enabled:
> `flutter config --enable-windows-desktop`

## 📦 Dependencies

```yaml
flutter_riverpod: ^2.4.0
drift: ^2.3.0
sqlite3_flutter_libs: any
path_provider: ^2.0.14
pdf: ^3.10.0
printing: ^5.10.0
image_picker: ^1.0.7
file_picker: ^6.1.1
```

---

## 🔐 License

This project is private and developed for internal use. Contact the owner for reuse or contributions.

---

## TODO
1. Allow multiple tabs in create invoice page
2. Add customer to database
3. Allow to search customer while creating invoice
4. Allow edit of invoice