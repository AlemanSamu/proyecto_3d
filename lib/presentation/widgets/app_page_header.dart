import 'package:flutter/material.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.badge,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badge != null) ...[badge!, const SizedBox(height: 12)],
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1.02,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.45,
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (trailing == null || constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              content,
              if (trailing != null) ...[
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: trailing!),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: content),
            const SizedBox(width: 16),
            trailing!,
          ],
        );
      },
    );
  }
}
