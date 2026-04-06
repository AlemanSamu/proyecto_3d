import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../domain/projects/project_model.dart';
import '../providers/project_providers.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_section_badge.dart';
import '../widgets/app_surface_card.dart';
import '../widgets/state_feedback_card.dart';
import '../widgets/status_badge.dart';

class ModelViewerScreen extends ConsumerStatefulWidget {
  const ModelViewerScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ModelViewerScreen> createState() => _ModelViewerScreenState();
}

class _ModelViewerScreenState extends ConsumerState<ModelViewerScreen> {
  bool _downloading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByIdProvider(widget.projectId));
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visor 3D')),
        body: const Center(child: Text('No se encontro el proyecto.')),
      );
    }

    final modelPath = project.modelPath;
    final modelExt = _fileExtension(modelPath);
    final fileExists = modelPath != null && File(modelPath).existsSync();
    final isSimulatedGlb = modelExt == 'glb' && _looksLikeSimulatedGlb(modelPath);

    return Scaffold(
      appBar: AppBar(title: const Text('Visor 3D')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          AppPageHeader(
            title: project.name,
            subtitle: 'Visualizacion del modelo final generado por el backend.',
            badge: AppSectionBadge(
              label: project.status.label,
              color: StatusBadge.colorFor(project.status),
              icon: Icons.view_in_ar_outlined,
            ),
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null) ...[
            StateFeedbackCard(
              title: 'Error de carga',
              message: _errorMessage ?? 'No se pudo cargar el modelo.',
              icon: Icons.error_outline_rounded,
              tint: const Color(0xFFFF7D7D),
              actionLabel: 'Reintentar',
              onAction: () => _downloadLatestModel(project),
            ),
            const SizedBox(height: 12),
          ],
          if (!fileExists)
            StateFeedbackCard(
              title: 'Modelo no disponible',
              message:
                  'Aun no hay un modelo descargado en el dispositivo para este proyecto.',
              icon: Icons.cloud_download_outlined,
              actionLabel: _downloading ? null : 'Descargar del backend',
              onAction: _downloading ? null : () => _downloadLatestModel(project),
            )
          else if (isSimulatedGlb)
            StateFeedbackCard(
              title: 'Modelo simulado',
              message:
                  'El backend aun usa un GLB simulado. El archivo existe, pero no es un modelo 3D real todavia.',
              icon: Icons.science_outlined,
              tint: const Color(0xFFFFB347),
            )
          else if (modelExt == 'glb')
            _GlbViewer(path: modelPath)
          else if (modelExt == 'obj')
            _ObjReadyCard(path: modelPath)
          else
            StateFeedbackCard(
              title: 'Formato no soportado',
              message:
                  'El visor actual esta preparado para GLB y ruta de OBJ. Formato detectado: .$modelExt',
              icon: Icons.warning_amber_rounded,
              tint: const Color(0xFFFFB347),
            ),
          const SizedBox(height: 12),
          AppSurfaceCard(
            title: 'Detalle del archivo',
            subtitle: modelPath ?? 'Sin ruta local disponible',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Line(label: 'Formato', value: modelExt.toUpperCase()),
                _Line(
                  label: 'Estado remoto',
                  value: project.remoteStatus ?? 'Sin estado remoto',
                ),
                _Line(
                  label: 'URL remota',
                  value: project.remoteModelUrl ?? 'No disponible',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _downloading
                        ? null
                        : () => _downloadLatestModel(project),
                    icon: _downloading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      _downloading ? 'Actualizando...' : 'Actualizar desde backend',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadLatestModel(ProjectModel project) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(projectBackendControllerProvider)
        .refreshStatus(project);

    if (!mounted) return;
    setState(() {
      _downloading = false;
      _errorMessage = result.success ? null : result.message;
    });
  }

  String _fileExtension(String? path) {
    if (path == null || path.trim().isEmpty) return 'desconocido';
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return 'desconocido';
    return path.substring(dot + 1).toLowerCase();
  }

  bool _looksLikeSimulatedGlb(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    try {
      final bytes = File(path).readAsBytesSync();
      const marker = 'SIMULATED_GLB';
      if (bytes.length < marker.length) return false;
      final head = String.fromCharCodes(bytes.take(marker.length));
      return head == marker;
    } catch (_) {
      return false;
    }
  }
}

class _GlbViewer extends StatelessWidget {
  const _GlbViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      title: 'Vista GLB',
      subtitle: 'Control de camara habilitado',
      child: SizedBox(
        height: 420,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ModelViewer(
            src: Uri.file(path).toString(),
            alt: 'Modelo 3D',
            autoRotate: true,
            cameraControls: true,
            disableZoom: false,
          ),
        ),
      ),
    );
  }
}

class _ObjReadyCard extends StatelessWidget {
  const _ObjReadyCard({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      title: 'OBJ detectado',
      subtitle: path,
      child: const Text(
        'El flujo ya acepta y descarga OBJ. El render embebido para OBJ queda preparado para el siguiente paso (GLB ya renderiza en esta version).',
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
