import 'package:flutter/material.dart';

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.accent = const Color(0xFF6C8EFF),
    this.helper,
    this.icon,
    this.centered = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  });

  final String label;
  final String value;
  final Color accent;
  final String? helper;
  final IconData? icon;
  final bool centered;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final alignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final labelAlign = centered ? TextAlign.center : TextAlign.left;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: accent),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            textAlign: labelAlign,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: labelAlign,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          if (helper != null) ...[
            const SizedBox(height: 6),
            Text(
              helper!,
              textAlign: labelAlign,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white60,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
