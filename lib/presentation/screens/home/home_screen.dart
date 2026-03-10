import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/projects/project_model.dart';
import '../../providers/project_providers.dart';
import '../capture/capture_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabIndex = 0;
  bool _showSearch = false;
  bool _doneOnly = false;
  String _query = '';

  Future<void> _openCapture() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CaptureScreen()));
  }

  String _formatDate(DateTime date) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final local = date.toLocal();
    final month = months[local.month - 1];
    return '$month ${local.day}';
  }

  List<ProjectModel> _galleryProjects(List<ProjectModel> projects) {
    final normalized = _query.trim().toLowerCase();
    return [
      for (final project in projects)
        if ((!_doneOnly || project.status == ProjectStatus.done) &&
            (normalized.isEmpty ||
                project.name.toLowerCase().contains(normalized)))
          project,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final notifier = ref.read(projectsProvider.notifier);

    final orderedProjects = [...projects]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final galleryProjects = _galleryProjects(orderedProjects);

    return Scaffold(
      extendBody: true,
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton(
              onPressed: _openCapture,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF222A3A), Color(0xFF0D1018)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tabIndex,
            children: [
              _HomeTab(
                projects: orderedProjects,
                onScanTap: _openCapture,
                onOpenGallery: () => setState(() => _tabIndex = 1),
                onOpenSettings: () => setState(() => _tabIndex = 2),
                formatDate: _formatDate,
              ),
              _GalleryTab(
                projects: galleryProjects,
                showSearch: _showSearch,
                query: _query,
                doneOnly: _doneOnly,
                onToggleSearch: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _query = '';
                  });
                },
                onToggleDoneOnly: () => setState(() => _doneOnly = !_doneOnly),
                onQueryChanged: (value) => setState(() => _query = value),
                formatDate: _formatDate,
              ),
              _SettingsTab(
                projects: orderedProjects,
                onOpenCapture: _openCapture,
                onDeleteProject: notifier.deleteProject,
                formatDate: _formatDate,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: _BottomDock(
          currentIndex: _tabIndex,
          onTap: (index) => setState(() => _tabIndex = index),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.projects,
    required this.onScanTap,
    required this.onOpenGallery,
    required this.onOpenSettings,
    required this.formatDate,
  });

  final List<ProjectModel> projects;
  final VoidCallback onScanTap;
  final VoidCallback onOpenGallery;
  final VoidCallback onOpenSettings;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = projects.isEmpty ? null : projects.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 126),
      children: [
        Row(
          children: [
            const SizedBox(width: 44),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'NombreAPP',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 36),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Convierte tus fotos en modelos 3D',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _HeroPreviewCard(project: latest),
        const SizedBox(height: 18),
        Center(
          child: ElevatedButton.icon(
            onPressed: onScanTap,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Escanear'),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Ultimos modelos',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
            ),
            const Spacer(),
            TextButton(
              onPressed: onOpenGallery,
              child: const Text('Ver galeria'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (projects.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF171B26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Text(
              'Aun no tienes proyectos. Pulsa Escanear para crear el primero.',
            ),
          )
        else
          SizedBox(
            height: 142,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: projects.length.clamp(0, 8),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final project = projects[index];
                return _RecentModelCard(
                  project: project,
                  dateLabel: formatDate(project.createdAt),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _GalleryTab extends StatelessWidget {
  const _GalleryTab({
    required this.projects,
    required this.showSearch,
    required this.query,
    required this.doneOnly,
    required this.onToggleSearch,
    required this.onToggleDoneOnly,
    required this.onQueryChanged,
    required this.formatDate,
  });

  final List<ProjectModel> projects;
  final bool showSearch;
  final String query;
  final bool doneOnly;
  final VoidCallback onToggleSearch;
  final VoidCallback onToggleDoneOnly;
  final ValueChanged<String> onQueryChanged;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Galeria',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 34),
              ),
              const Spacer(),
              _TopIconButton(
                active: showSearch,
                icon: Icons.search_rounded,
                onTap: onToggleSearch,
              ),
              const SizedBox(width: 8),
              _TopIconButton(
                active: doneOnly,
                icon: Icons.tune_rounded,
                onTap: onToggleDoneOnly,
              ),
            ],
          ),
          if (showSearch) ...[
            const SizedBox(height: 12),
            TextField(
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Buscar proyecto...',
                suffixText: query.isEmpty ? null : '${projects.length}',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: projects.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171B26),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        doneOnly
                            ? 'No hay modelos terminados.'
                            : 'Sin modelos escaneados.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(bottom: 140),
                    itemCount: projects.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.74,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemBuilder: (_, index) {
                      final project = projects[index];
                      return _GalleryModelCard(
                        project: project,
                        dateLabel: formatDate(project.createdAt),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.projects,
    required this.onOpenCapture,
    required this.onDeleteProject,
    required this.formatDate,
  });

  final List<ProjectModel> projects;
  final VoidCallback onOpenCapture;
  final ValueChanged<String> onDeleteProject;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 126),
      children: [
        Text(
          'Ajustes',
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 34),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF171B26),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Inicia una nueva sesion de escaneo desde aqui.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onOpenCapture,
                child: const Text('Nuevo'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Proyectos',
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 10),
        if (projects.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF171B26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Text('No hay proyectos creados.'),
          )
        else
          ...projects.map(
            (project) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF171B26),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    _StatusDot(status: project.status),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatDate(project.createdAt)} | ${project.status.label}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: () => onDeleteProject(project.id),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BottomDock extends StatelessWidget {
  const _BottomDock({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141925).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 12),
            color: Colors.black.withValues(alpha: 0.35),
          ),
        ],
      ),
      child: Row(
        children: [
          _BottomItem(
            selected: currentIndex == 0,
            icon: Icons.home_filled,
            label: 'Inicio',
            onTap: () => onTap(0),
          ),
          _BottomItem(
            selected: currentIndex == 1,
            icon: Icons.photo_library_rounded,
            label: 'Galeria',
            onTap: () => onTap(1),
          ),
          _BottomItem(
            selected: currentIndex == 2,
            icon: Icons.settings_rounded,
            label: 'Ajustes',
            onTap: () => onTap(2),
          ),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = selected ? Colors.white : const Color(0xFF8E97AA);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: activeColor, size: 20),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: activeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPreviewCard extends StatelessWidget {
  const _HeroPreviewCard({required this.project});

  final ProjectModel? project;

  @override
  Widget build(BuildContext context) {
    final imagePath = project?.imagePaths.isNotEmpty == true
        ? project!.imagePaths.last
        : null;

    return Container(
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF262F46), Color(0xFF121724)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 12),
            color: Colors.black.withValues(alpha: 0.35),
          ),
        ],
      ),
      child: Center(
        child: imagePath == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.view_in_ar_rounded,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.64),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tu vista previa aparecera aqui',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    cacheWidth: 720,
                    cacheHeight: 720,
                    width: double.infinity,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF111727),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_rounded),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _RecentModelCard extends StatelessWidget {
  const _RecentModelCard({required this.project, required this.dateLabel});

  final ProjectModel project;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final thumbPath = project.imagePaths.isNotEmpty
        ? project.imagePaths.last
        : null;

    return Container(
      width: 110,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: thumbPath == null
                  ? Container(
                      color: const Color(0xFF101420),
                      child: const Center(
                        child: Icon(Icons.image_not_supported_rounded),
                      ),
                    )
                  : Image.file(
                      File(thumbPath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      cacheWidth: 300,
                      cacheHeight: 300,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFF101420),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _GalleryModelCard extends StatelessWidget {
  const _GalleryModelCard({required this.project, required this.dateLabel});

  final ProjectModel project;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final thumbPath = project.imagePaths.isNotEmpty
        ? project.imagePaths.last
        : null;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Proyecto: ${project.name}'),
                duration: const Duration(milliseconds: 1200),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: thumbPath == null
                        ? Container(
                            color: const Color(0xFF101420),
                            child: const Center(
                              child: Icon(
                                Icons.photo_size_select_actual_rounded,
                              ),
                            ),
                          )
                        : Image.file(
                            File(thumbPath),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            cacheWidth: 600,
                            cacheHeight: 600,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFF101420),
                              child: const Center(
                                child: Icon(Icons.broken_image_rounded),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(dateLabel, style: theme.textTheme.bodySmall),
                    ),
                    _StatusDot(status: project.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ProjectStatus.capturing => const Color(0xFF6C4DFF),
      ProjectStatus.processing => const Color(0xFFFFAB3D),
      ProjectStatus.done => const Color(0xFF57D682),
      ProjectStatus.error => const Color(0xFFFF5D5D),
    };

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.active,
    required this.icon,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Ink(
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
            : const Color(0xFF171B26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}
