class BackendApiException implements Exception {
  const BackendApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  final String message;
  final int? statusCode;
  final String? details;

  bool get isNetwork => statusCode == null;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (HTTP $statusCode)';
    final extra = details == null || details!.trim().isEmpty
        ? ''
        : ': $details';
    return 'BackendApiException$code: $message$extra';
  }
}
