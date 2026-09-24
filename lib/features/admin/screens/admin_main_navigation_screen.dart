import 'package:flutter/material.dart';
import 'package:vitanet/features/admin/screens/admin_home_page.dart';
import 'package:vitanet/features/admin/screens/admin_notifications_page.dart';
import 'package:vitanet/features/admin/screens/admin_patient_data_page.dart';
import 'package:vitanet/features/admin/screens/admin_infrastructure_page.dart';
import 'package:vitanet/features/admin/screens/admin_settings_page.dart';

class AdminMainNavigationScreen extends StatefulWidget {
  const AdminMainNavigationScreen({super.key});

  @override
  State<AdminMainNavigationScreen> createState() => _AdminMainNavigationScreenState();
}

class _AdminMainNavigationScreenState extends State<AdminMainNavigationScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const AdminHomePage(),
      const AdminNotificationsPage(),
      const AdminPatientDataPage(),
      const AdminInfrastructurePage(),
      AdminSettingsPage(
        onThemeChanged: (theme) {}, // Placeholder for theme change
        currentThemeMode: ThemeMode.system,
        onNavigateToNotifications: () => _onItemTapped(1),
      ),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_outlined),
            activeIcon: Icon(Icons.business),
            label: 'Hospital',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
