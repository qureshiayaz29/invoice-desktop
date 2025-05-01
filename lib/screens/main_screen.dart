import 'package:flutter/material.dart';
import 'package:invoice_generator/screens/edit_screen.dart';
import 'package:invoice_generator/screens/home_page.dart';
import 'package:invoice_generator/screens/invoice_create_screen.dart'; // Import create invoice screen
import 'package:invoice_generator/screens/invoice_history_screen.dart'; // Import history screen

// StatefulWidget for the main screen containing the bottom navigation bar.
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// State class for the HomeScreen.
class _MainScreenState extends State<MainScreen> {
  // Index of the currently selected tab in the bottom navigation bar.
  int _selectedIndex = 0;

  // List of the main screen widgets corresponding to each tab.
  // Using const for potentially better performance if widgets are simple.
  static const List<Widget> _pages = <Widget>[
    HomePage(), // Screen for the "Create" tab (index 0)
    InvoiceCreateScreen(), // Screen for the "Create" tab (index 0)
    InvoiceHistoryScreen(), // Screen for the "History" tab (index 1)
    EditScreen(), // Screen for the "Shop Details" tab (index 2)
  ];

  // Titles corresponding to each page/tab.
  static const List<String> _pageTitles = <String>[
    'Home',
    'Create New Invoice',
    'Invoice History',
    'Settings',
  ];

  // Callback function when a bottom navigation bar item is tapped.
  void _onItemTapped(int index) {
    // Update the state to change the selected index, triggering a rebuild.
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Always visible Drawer
          Drawer(
            backgroundColor: Theme.of(context).primaryColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(0), // No rounding on top-right
              ),
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                  child: const Text(
                    'Invoice Generator',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 2.0),
                  child: ListTile(
                    leading: const Icon(
                      Icons.home,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Home',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedIndex = 0;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 2.0),
                  child: ListTile(
                    leading: const Icon(
                      Icons.note_add,
                      color: Colors.white,
                    ),
                    title: const Text('Create Invoice',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      setState(() {
                        _selectedIndex = 1;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 2.0),
                  child: ListTile(
                    leading: const Icon(Icons.history, color: Colors.white),
                    title: const Text('All invoices',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      setState(() {
                        _selectedIndex = 2;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 2.0),
                  child: ListTile(
                    leading: const Icon(Icons.edit, color: Colors.white),
                    title: const Text('Shop Details',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      setState(() {
                        _selectedIndex = 3;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}
