import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/domain/projects/project_model.dart';
import 'package:proyecto_3d/domain/projects/reconstruction_result.dart';

void main() {
  test('detects error reconstruction state', () {
    final project = ProjectModel(
      id: 'p1',
      name: 'demo',
      createdAt: DateTime(2026),
      status: ProjectStatus.error,
    );

    expect(project.reconstructionResult, ReconstructionResultKind.error);
  });

  test('marks simulated glb as approximate', () async {
    final temp = await Directory.systemTemp.createTemp('recon_test_');
    final file = File('${temp.path}/simulated.glb');
    await file.writeAsString('SIMULATED_GLB_payload');

    final project = ProjectModel(
      id: 'p2',
      name: 'demo',
      createdAt: DateTime(2026),
      status: ProjectStatus.modelGenerated,
      modelPath: file.path,
      remoteStatus: 'completed',
    );

    expect(project.reconstructionResult, ReconstructionResultKind.approximate);
  });

  test('marks completed model as real reconstruction', () {
    final project = ProjectModel(
      id: 'p3',
      name: 'demo',
      createdAt: DateTime(2026),
      status: ProjectStatus.modelGenerated,
      modelPath: '/tmp/model_real.glb',
      remoteStatus: 'completed_dense',
    );

    expect(project.reconstructionResult, ReconstructionResultKind.real);
  });
}
