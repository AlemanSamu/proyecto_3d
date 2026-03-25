import 'package:flutter/material.dart';

import 'app_destination.dart';
import 'capture/capture_screen.dart';
import 'home/home_screen.dart';
import 'models/models_screen.dart';
import 'project_workspace_screen.dart';
import 'projects_hub_screen.dart';
import 'system_settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppDestination _currentDestination = AppDestination.home;
  final _destinations = AppDestination.values;

  int get _currentIndex => AppDestination.values.indexOf(_currentDestination);

  Future<void> _openProjectDetail(String projectId) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectWorkspaceScreen(projectId: projectId),
      ),
    );
  }

  void _goToTab(int index) {
    final destination = _destinations[index];
    if (destination == _currentDestination) return;
    setState(() => _currentDestination = destination);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      HomeScreen(onNavigateToTab: _goToTab, onOpenProject: _openProjectDetail),
      const CaptureScreen(),
      ProjectsHubScreen(onOpenProject: _openProjectDetail),
      const ModelsScreen(),
      const SystemSettingsScreen(),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101926), Color(0xFF08111A)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: IndexedStack(index: _currentIndex, children: tabs),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF243446))),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _goToTab,
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}
