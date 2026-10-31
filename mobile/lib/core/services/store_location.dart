import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Accept only Maps destinations from admin data; never launch arbitrary schemes.
Uri? storeLocationUri({String? mapsUrl, String? name, String? address}) {
  final explicitPort = RegExp(
    r'^https://[^/?#]*:',
    caseSensitive: false,
  ).hasMatch(mapsUrl?.trim() ?? '');
  final uri = Uri.tryParse(mapsUrl?.trim() ?? '');
  if (uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      !explicitPort) {
    final host = uri.host.toLowerCase();
    final isMaps =
        host == 'maps.app.goo.gl' ||
        (host == 'goo.gl' && uri.path.startsWith('/maps')) ||
        ((host == 'google.com' ||
                host == 'www.google.com' ||
                host == 'google.com.pk' ||
                host == 'www.google.com.pk') &&
            (uri.path == '/maps' || uri.path.startsWith('/maps/'))) ||
        host == 'maps.google.com' ||
        host == 'maps.google.com.pk';
    if (isMaps) return uri;
  }
  if (address?.trim().isNotEmpty != true) return null;
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': [
      name?.trim(),
      address!.trim(),
    ].whereType<String>().where((v) => v.isNotEmpty).join(', '),
  });
}

Future<void> openStoreLocation(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    /* Surface a useful failure rather than silently ignoring it. */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open Google Maps. Please try again.'),
      ),
    );
  }
}
