class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

String readableError(Object error) {
  if (error is AppException) return error.message;
  return 'No pudimos completar la operación. Intentá nuevamente.';
}
