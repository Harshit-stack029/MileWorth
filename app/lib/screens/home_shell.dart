import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';
import 'add_trip_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'trips_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Lets a child tab (e.g. the dashboard) switch the selected bottom-nav tab.
  static void goToTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_HomeShellState>()?._setIndex(index);
  }

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _setIndex(int i) => setState(() => _index = i);

  static const _titles = ['Dashboard', 'Trips', 'Expenses', 'Reports', 'Settings'];
  static const _pages = [
    DashboardScreen(),
    TripsScreen(),
    ExpensesScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  Widget? _fab() {
    switch (_index) {
      case 1: // Trips
        return FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddTripScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add trip'),
        );
      case 2: // Expenses
        return FloatingActionButton.extended(
          onPressed: () => openAddExpense(context),
          icon: const Icon(Icons.add),
          label: const Text('Add expense'),
        );
      default:
        return null;
    }
  }

  // On the dashboard, show the brand lockup; elsewhere the plain tab title.
  Widget _titleWidget() {
    if (_index != 0) return Text(_titles[_index]);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset('assets/brand/icon.svg', height: 28),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(children: const [
            TextSpan(text: 'Mile'),
            TextSpan(text: 'Worth', style: TextStyle(color: AppColors.green)),
          ]),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.navyDeep,
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: _titleWidget()),
      body: _pages[_index],
      floatingActionButton: _fab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
