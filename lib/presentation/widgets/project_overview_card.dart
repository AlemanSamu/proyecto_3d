import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/projects/project_model.dart';
import '../../domain/projects/project_workflow.dart';
import '../utils/presentation_formatters.dart';
import 'app_info_chip.dart';
import 'status_badge.dart';

class ProjectOverviewCard extends StatelessWidget {
  const ProjectOverviewCard({
    super.key,
    required this.project,
    required this.onTap,
    this.compact = false,
    this.trailing,
  });

  final ProjectModel project;
  final VoidCallback onTap;
  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final imagePath =
        project.coverImagePath ??
        (project.photos.isNotEmpty
            ? (project.photos.last.thumbnailPath.isNotEmpty
                  ? project.photos.last.thumbnailPath
                  : project.photos.last.originalPath)
            : null);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xD9111B27),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF243446)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: compact ? 86 : 98,
                  height: compact ? 92 : 104,
                  child: imagePath == null || imagePath.isEmpty
                      ? Container(
                          color: const Color(0xFF0F1420),
                          alignment: Alignment.center,
                          child: const Icon(Icons.photo_size_select_actual),
                        )
                      : Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          cacheWidth: 360,
                          cacheHeight: 360,
                          errorBuilder: (_, _, _) => Container(
                            color: const Color(0xFF0F1420),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontSize: compact ? 16 : 18,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: project.status, compact: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.description.isEmpty
                          ? 'Actualizado ${formatShortDate(project.updatedAt)}'
                          : project.description,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppInfoChip(
                          label: '${project.photos.length} capturas',
                          color: const Color(0xFF76A7FF),
                          icon: Icons.photo_library_outlined,
                        ),
                        AppInfoChip(
                          label: '${project.coverage.acceptedPhotos} aceptadas',
                          color: const Color(0xFF57D684),
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        if (project.coverage.flaggedForRetake > 0)
                          AppInfoChip(
                            label:
                                '${project.coverage.flaggedForRetake} retake',
                            color: const Color(0xFFFFB347),
                            icon: Icons.flag_outlined,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      project.primaryActionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
