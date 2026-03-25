import 'package:flutter/material.dart';

import '../../domain/projects/project_model.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.compact = false});

  final ProjectStatus status;
  final bool compact;

  static Color colorFor(ProjectStatus status) {
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

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    final vertical = compact ? 4.0 : 6.0;
    final horizontal = compact ? 8.0 : 11.0;
    final fontSize = compact ? 11.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 7 : 8,
            height: compact ? 7 : 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
