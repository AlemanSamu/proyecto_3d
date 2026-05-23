import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/projects/project_capture_readiness.dart';
import '../../providers/project_providers.dart';
import '../../widgets/app_surface_card.dart';
import '../processing_progress_screen.dart';

class CaptureSummaryScreen extends ConsumerStatefulWidget {
  const CaptureSummaryScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<CaptureSummaryScreen> createState() =>
      _CaptureSummaryScreenState();
}

class _CaptureSummaryScreenState extends ConsumerState<CaptureSummaryScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByIdProvider(widget.projectId));
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resumen')),
        body: const Center(child: Text('No se encontro el proyecto.')),
      );
    }

    final readiness = ProjectCaptureReadiness.fromProject(project);
    final warningPhotos = project.photos
        .where((photo) => photo.warnings.isNotEmpty)
        .length;
    final recommendation = _buildRecommendation(
      readiness: readiness,
      warningPhotos: warningPhotos,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen antes de enviar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            project.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa calidad y cobertura antes de enviar al backend.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          AppSurfaceCard(
            title: 'Resumen',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line('Fotos aceptadas', '${readiness.acceptedPhotos}'),
                _line('Fotos con advertencias', '$warningPhotos'),
                _line(
                  'Bajo / Medio / Alto',
                  '${readiness.lowAngleCount} / ${readiness.midAngleCount} / ${readiness.highAngleCount}',
                ),
                _line(
                  'Calidad promedio',
                  'Brillo ${readiness.averageBrightness.toStringAsFixed(0)} | Nitidez ${readiness.averageSharpness.toStringAsFixed(0)}',
                ),
                _line(
                  'Resolucion promedio',
                  readiness.averageMegapixels <= 0
                      ? 'Sin datos'
                      : '${readiness.averageMegapixels.toStringAsFixed(1)} MP',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppSurfaceCard(
            title: 'Recomendacion',
            child: Text(
              recommendation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _submitting ? null : () => _submit(project.id),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Enviar al backend'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tomar mas fotos'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 165,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildRecommendation({
    required ProjectCaptureReadiness readiness,
    required int warningPhotos,
  }) {
    if (warningPhotos >= 4) {
      return 'Hay varias fotos borrosas';
    }
    if (readiness.highAngleCount < 8) {
      return 'Puedes mejorar con mas fotos desde arriba';
    }
    return 'Listo para enviar';
  }

  Future<void> _submit(String projectId) async {
    if (_submitting) return;
    final project = ref.read(projectByIdProvider(projectId));
    if (project == null) return;

    setState(() => _submitting = true);
    final result = await ref
        .read(projectBackendControllerProvider)
        .submitForProcessing(project);

    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));

    if (!result.success) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProcessingProgressScreen(projectId: projectId),
      ),
    );
  }
}
