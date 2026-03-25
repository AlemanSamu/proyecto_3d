import 'package:flutter/material.dart';

import '../../domain/projects/project_export_config.dart';
import 'app_info_chip.dart';
import 'app_surface_card.dart';

class ExportConfigurationPanel extends StatelessWidget {
  const ExportConfigurationPanel({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final ProjectExportConfig config;
  final ValueChanged<ProjectExportConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      title: 'Configuracion de exportacion',
      subtitle: 'Define formato, calidad y destino de salida',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppInfoChip(
                label: config.targetFormat.label,
                color: const Color(0xFF8F7BFF),
                icon: Icons.view_in_ar_outlined,
              ),
              AppInfoChip(
                label: config.qualityPreset.label,
                color: const Color(0xFF4D92FF),
                icon: Icons.auto_awesome_outlined,
              ),
              AppInfoChip(
                label: config.destination.label,
                color: const Color(0xFF41D4B8),
                icon: Icons.outbox_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ResponsiveFieldWrap(
            children: [
              _DropdownField<ExportTargetFormat>(
                label: 'Formato',
                value: config.targetFormat,
                options: ExportTargetFormat.values,
                labelBuilder: (value) => value.label,
                onChanged: (value) =>
                    onChanged(config.copyWith(targetFormat: value)),
              ),
              _DropdownField<ExportQualityPreset>(
                label: 'Calidad',
                value: config.qualityPreset,
                options: ExportQualityPreset.values,
                labelBuilder: (value) => value.label,
                onChanged: (value) =>
                    onChanged(config.copyWith(qualityPreset: value)),
              ),
              _DropdownField<TextureQuality>(
                label: 'Texturas',
                value: config.textureQuality,
                options: TextureQuality.values,
                labelBuilder: (value) => value.label,
                onChanged: (value) =>
                    onChanged(config.copyWith(textureQuality: value)),
              ),
              _DropdownField<GeometryQuality>(
                label: 'Geometria',
                value: config.geometryQuality,
                options: GeometryQuality.values,
                labelBuilder: (value) => value.label,
                onChanged: (value) =>
                    onChanged(config.copyWith(geometryQuality: value)),
              ),
              _DropdownField<ExportScaleUnit>(
                label: 'Escala',
                value: config.scaleUnit,
                options: ExportScaleUnit.values,
                labelBuilder: (value) => value.label,
                onChanged: (value) =>
                    onChanged(config.copyWith(scaleUnit: value)),
              ),
              _DropdownField<ExportDestination>(
                label: 'Destino',
                value: config.destination,
                options: ExportDestination.values,
                labelBuilder: (value) => value.label,
                onChanged: (value) =>
                    onChanged(config.copyWith(destination: value)),
              ),
            ],
          ),
          if (config.destination == ExportDestination.localServer) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: config.destinationPath,
              onChanged: (value) {
                final normalized = value.trim();
                onChanged(
                  config.copyWith(
                    destinationPath: normalized.isEmpty ? null : normalized,
                    clearDestinationPath: normalized.isEmpty,
                  ),
                );
              },
              decoration: const InputDecoration(
                labelText: 'Ruta/Endpoint destino',
                hintText: 'http://192.168.1.120:8080/upload',
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF41D4B8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF41D4B8).withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                'Usa el endpoint del servidor local para entregar el paquete final o automatizar sincronizacion posterior.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _ConfigSwitch(
            label: 'Incluir imagenes originales',
            value: config.includeImages,
            onChanged: (value) =>
                onChanged(config.copyWith(includeImages: value)),
          ),
          _ConfigSwitch(
            label: 'Incluir miniaturas',
            value: config.includeThumbnails,
            onChanged: (value) =>
                onChanged(config.copyWith(includeThumbnails: value)),
          ),
          _ConfigSwitch(
            label: 'Incluir metadatos de captura',
            value: config.includeMetadata,
            onChanged: (value) =>
                onChanged(config.copyWith(includeMetadata: value)),
          ),
          _ConfigSwitch(
            label: 'Incluir normales',
            value: config.includeNormals,
            onChanged: (value) =>
                onChanged(config.copyWith(includeNormals: value)),
          ),
          _ConfigSwitch(
            label: 'Comprimir paquete',
            value: config.compressPackage,
            onChanged: (value) =>
                onChanged(config.copyWith(compressPackage: value)),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveFieldWrap extends StatelessWidget {
  const _ResponsiveFieldWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final fieldWidth = wide
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final child in children)
              SizedBox(width: fieldWidth, child: child),
          ],
        );
      },
    );
  }
}

class _ConfigSwitch extends StatelessWidget {
  const _ConfigSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(label),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(labelBuilder(option))),
      ],
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
    );
  }
}
