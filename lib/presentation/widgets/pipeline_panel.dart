import 'package:flutter/material.dart';

import '../../domain/projects/project_export_config.dart';
import '../../domain/projects/project_model.dart';
import '../../domain/projects/project_processing.dart';
import '../../domain/projects/project_workflow.dart';
import 'app_info_chip.dart';
import 'app_surface_card.dart';

class PipelinePanel extends StatelessWidget {
  const PipelinePanel({super.key, required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final steps = project.workflowSteps;
    final stageColor = _stageColor(project.processingState.stage);

    return AppSurfaceCard(
      title: 'Pipeline del proyecto',
      subtitle: 'Flujo operativo desde la captura hasta el paquete final',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppInfoChip(
                label: project.status.label,
                color: StatusColors.status(project.status),
                icon: Icons.radar_rounded,
              ),
              AppInfoChip(
                label: project.processingConfig.profile.label,
                color: const Color(0xFF8F7BFF),
                icon: Icons.tune_rounded,
              ),
              AppInfoChip(
                label: project.exportConfig.targetFormat.label,
                color: const Color(0xFF4D92FF),
                icon: Icons.archive_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int index = 0; index < steps.length; index++)
            _PipelineStepTile(
              step: steps[index],
              isLast: index == steps.length - 1,
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: stageColor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: stageColor.withValues(alpha: 0.24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _stageIcon(project.processingState.stage),
                      size: 16,
                      color: stageColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        project.processingState.stage.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${(project.processingState.progress * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  project.processingState.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: project.processingState.progress == 0
                        ? null
                        : project.processingState.progress,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(stageColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _stageIcon(ProcessingStage stage) {
    return switch (stage) {
      ProcessingStage.idle => Icons.pause_circle_outline_rounded,
      ProcessingStage.queued => Icons.schedule_rounded,
      ProcessingStage.preparing => Icons.inventory_2_outlined,
      ProcessingStage.reconstructing => Icons.grid_4x4_rounded,
      ProcessingStage.texturing => Icons.texture_rounded,
      ProcessingStage.packaging => Icons.archive_outlined,
      ProcessingStage.completed => Icons.check_circle_rounded,
      ProcessingStage.failed => Icons.error_outline_rounded,
    };
  }

  static Color _stageColor(ProcessingStage stage) {
    return switch (stage) {
      ProcessingStage.completed => const Color(0xFF57D684),
      ProcessingStage.failed => const Color(0xFFFF6E6E),
      ProcessingStage.packaging => const Color(0xFFFFB347),
      ProcessingStage.reconstructing => const Color(0xFF6C8EFF),
      _ => const Color(0xFFC6CCDA),
    };
  }
}

class StatusColors {
  static Color status(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.draft => const Color(0xFF9AA5BD),
      ProjectStatus.capturing => const Color(0xFF6B74FF),
      ProjectStatus.reviewReady => const Color(0xFF8F7BFF),
      ProjectStatus.readyToProcess => const Color(0xFF4D92FF),
      ProjectStatus.processing => const Color(0xFFFFB347),
      ProjectStatus.modelGenerated => const Color(0xFF41D4B8),
      ProjectStatus.exported => const Color(0xFF57D684),
      ProjectStatus.error => const Color(0xFFFF6E6E),
    };
  }
}

class _PipelineStepTile extends StatelessWidget {
  const _PipelineStepTile({required this.step, required this.isLast});

  final ProjectFlowStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.state) {
      ProjectFlowStepState.completed => const Color(0xFF57D684),
      ProjectFlowStepState.current => Theme.of(context).colorScheme.primary,
      ProjectFlowStepState.pending => const Color(0xFF8C96AF),
      ProjectFlowStepState.blocked => const Color(0xFF596173),
      ProjectFlowStepState.error => const Color(0xFFFF6E6E),
    };
    final icon = switch (step.state) {
      ProjectFlowStepState.completed => Icons.check_circle_rounded,
      ProjectFlowStepState.current => Icons.radio_button_checked_rounded,
      ProjectFlowStepState.pending => Icons.radio_button_unchecked_rounded,
      ProjectFlowStepState.blocked => Icons.lock_outline_rounded,
      ProjectFlowStepState.error => Icons.error_outline_rounded,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, size: 18, color: color),
            if (!isLast)
              Container(
                width: 2,
                height: 26,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.white12,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
