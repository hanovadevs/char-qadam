/// QR contents are data, never a URL to open or a redemption command.
String? voucherScanValue(String? raw) {
  if (raw == null || raw.length > 2048) return null;
  var value = raw.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) {
    if (uri.scheme != 'https' ||
        !{'stepsyapp.com', 'stepsy.app'}.contains(uri.host) ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'v') {
      return null;
    }
    value = uri.pathSegments.last;
  }
  final code = value.toUpperCase();
  if (RegExp(r'^SR-[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(code)) return code;
  if (RegExp(r'^[A-Za-z0-9_-]{20,256}$').hasMatch(value)) return value;
  return null;
}
