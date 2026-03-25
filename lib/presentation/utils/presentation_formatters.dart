String formatShortDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${formatShortDate(local)} $hour:$minute';
}

String formatCaptureLevel(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'top':
      return 'Alta';
    case 'mid':
      return 'Media';
    case 'low':
      return 'Baja';
    default:
      if (value == null || value.trim().isEmpty) return '--';
      final normalized = value.trim();
      return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

String formatCaptureDescriptor({String? level, int? angleDeg}) {
  final levelLabel = formatCaptureLevel(level);
  final angleLabel = angleDeg == null ? '--' : '$angleDeg deg';
  return '$levelLabel - $angleLabel';
}
