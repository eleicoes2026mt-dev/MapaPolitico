/// Implementação não-web (mobile/desktop): sem fragmento de redirect do browser.
Uri currentUriWithFragment() => Uri.base;

void replaceBrowserPath(String path) {}

String? _pendingAuthErrorMobile;

void storePendingAuthErrorMessage(String message) {
  _pendingAuthErrorMobile = message;
}

String? takePendingAuthErrorMessage() {
  final v = _pendingAuthErrorMobile;
  _pendingAuthErrorMobile = null;
  return v;
}
