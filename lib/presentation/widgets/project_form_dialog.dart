import 'package:flutter/material.dart';

class ProjectFormResult {
  const ProjectFormResult({required this.name, required this.description});

  final String name;
  final String description;
}

Future<ProjectFormResult?> showProjectFormDialog(
  BuildContext context, {
  required String title,
  String confirmLabel = 'Guardar',
  String initialName = '',
  String initialDescription = '',
  String nameHint = 'Ejemplo: Silla de oficina',
  String descriptionHint = 'Objetivo, condiciones o notas de captura',
}) {
  return showDialog<ProjectFormResult?>(
    context: context,
    builder: (_) => _ProjectFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      initialDescription: initialDescription,
      nameHint: nameHint,
      descriptionHint: descriptionHint,
    ),
  );
}

class _ProjectFormDialog extends StatefulWidget {
  const _ProjectFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.initialDescription,
    required this.nameHint,
    required this.descriptionHint,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final String initialDescription;
  final String nameHint;
  final String descriptionHint;

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nombre del proyecto',
                  hintText: widget.nameHint,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Descripcion',
                  hintText: widget.descriptionHint,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).pop(
      ProjectFormResult(
        name: name,
        description: _descriptionController.text.trim(),
      ),
    );
  }
}
