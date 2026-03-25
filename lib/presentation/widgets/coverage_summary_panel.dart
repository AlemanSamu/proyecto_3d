import 'package:flutter/material.dart';

import '../../domain/projects/project_coverage_summary.dart';
import 'app_info_chip.dart';
import 'app_metric_card.dart';
import 'app_surface_card.dart';

class CoverageSummaryPanel extends StatelessWidget {
  const CoverageSummaryPanel({
    super.key,
    required this.summary,
    this.title = 'Resumen de cobertura',
  });

  final ProjectCoverageSummary summary;
  final String title;

  @override
  Widget build(BuildContext context) {
    final missing = (summary.minRecommendedPhotos - summary.acceptedPhotos)
        .clamp(0, summary.minRecommendedPhotos);
    final rejected = summary.flaggedForRetake;
    final pending = summary.pendingReviewPhotos.clamp(0, summary.totalPhotos);
    final coverageLabel = '${(summary.completion * 100).round()}%';
    final readinessMessage = summary.hasMinimumCoverage
        ? 'Cobertura minima alcanzada. El proyecto puede pasar a revision o procesamiento.'
        : 'Faltan $missing capturas aceptadas para cumplir la cobertura minima recomendada.';

    return AppSurfaceCard(
      title: title,
      subtitle: 'Cobertura compacta del lote actual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                coverageLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  readinessMessage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: summary.completion,
              minHeight: 7,
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 132,
                child: AppMetricCard(
                  label: 'Aceptadas',
                  value: '${summary.acceptedPhotos}',
                  accent: const Color(0xFF57D684),
                ),
              ),
              SizedBox(
                width: 132,
                child: AppMetricCard(
                  label: 'Retake',
                  value: '$rejected',
                  accent: const Color(0xFFFFA565),
                ),
              ),
              SizedBox(
                width: 132,
                child: AppMetricCard(
                  label: 'Faltantes',
                  value: '$missing',
                  accent: const Color(0xFF76A7FF),
                ),
              ),
              SizedBox(
                width: 132,
                child: AppMetricCard(
                  label: 'Pendientes',
                  value: '$pending',
                  accent: const Color(0xFF9FA8C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppInfoChip(
                label: '${summary.uniqueAngles} angulos',
                color: const Color(0xFF7A8CFF),
                icon: Icons.threesixty_rounded,
              ),
              AppInfoChip(
                label: '${summary.uniqueLevels} niveles',
                color: const Color(0xFF4FD3C1),
                icon: Icons.layers_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
