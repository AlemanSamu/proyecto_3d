import 'package:flutter/material.dart';

enum AppDestination { home, capture, projects, models, settings }

extension AppDestinationX on AppDestination {
  String get label => switch (this) {
    AppDestination.home => 'Inicio',
    AppDestination.capture => 'Capturar',
    AppDestination.projects => 'Proyectos',
    AppDestination.models => 'Modelos',
    AppDestination.settings => 'Ajustes',
  };

  String get headline => switch (this) {
    AppDestination.home => 'Inicio operativo',
    AppDestination.capture => 'Captura guiada',
    AppDestination.projects => 'Tablero de proyectos',
    AppDestination.models => 'Artefactos 3D',
    AppDestination.settings => 'Ajustes del sistema',
  };

  IconData get icon => switch (this) {
    AppDestination.home => Icons.space_dashboard_outlined,
    AppDestination.capture => Icons.camera_alt_outlined,
    AppDestination.projects => Icons.folder_outlined,
    AppDestination.models => Icons.view_in_ar_outlined,
    AppDestination.settings => Icons.settings_outlined,
  };

  IconData get selectedIcon => switch (this) {
    AppDestination.home => Icons.space_dashboard_rounded,
    AppDestination.capture => Icons.camera_alt_rounded,
    AppDestination.projects => Icons.folder_rounded,
    AppDestination.models => Icons.view_in_ar_rounded,
    AppDestination.settings => Icons.settings_rounded,
  };
}
