import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App-scoped Android identity, preserved by Android across ordinary reinstalls.
/// A cached copy allows a headless WorkManager isolate to use the same identity.
class DeviceIdentity {
  static const storageKey = 'stepsy_device_key_v1';
  static const _channel = MethodChannel('stepsy/device_identity');
  final Future<String> Function()? loader;
  Future<String>? _pending;

  DeviceIdentity({this.loader});

  Future<String> getKey() => _pending ??= _load().onError((error, stack) {
    _pending = null;
    Error.throwWithStackTrace(
      error ?? StateError('Device identity unavailable'),
      stack,
    );
  });

  Future<String> _load() async {
    final value = loader != null
        ? await loader!()
        : await _channel.invokeMethod<String>('fingerprint');
    if (value == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw StateError('Device identity unavailable. Please restart Stepsy.');
    }
    if (loader == null) {
      await const FlutterSecureStorage().write(key: storageKey, value: value);
    }
    return value;
  }

  static Future<String?> getBackgroundKey() async {
    final value = await const FlutterSecureStorage().read(key: storageKey);
    return value != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(value)
        ? value
        : null;
  }
}
