import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../voucher_scan_value.dart';

class MerchantScannerScreen extends StatefulWidget {
  const MerchantScannerScreen({super.key});
  @override
  State<MerchantScannerScreen> createState() => _MerchantScannerScreenState();
}

class _MerchantScannerScreenState extends State<MerchantScannerScreen>
    with WidgetsBindingObserver {
  final _camera = MobileScannerController(
    autoStart: false,
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  StreamSubscription<BarcodeCapture>? _subscription;
  bool _handled = false;
  String? _hint;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _camera.barcodes.listen(_detected);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _camera.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => _hint =
              'Camera access is unavailable. Allow it in app settings or enter the voucher code instead.',
        );
      }
    }
  }

  void _detected(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = voucherScanValue(barcode.rawValue);
      if (value != null) {
        _handled = true;
        unawaited(_camera.stop());
        context.pop(value);
        return;
      }
    }
    setState(
      () => _hint =
          'This is not a Stepsy voucher. Try another QR, or enter its code on the terminal.',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_camera.value.hasCameraPermission || _handled) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_start());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_camera.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan voucher')),
    body: Column(
      children: [
        Expanded(
          child: ClipRect(
            child: MobileScanner(
              controller: _camera,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 42,
                        color: AppTheme.accentSolid,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Allow camera access to scan a voucher. You can also enter its code on the terminal.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _start,
                        child: const Text('Retry camera'),
                      ),
                      OutlinedButton(
                        onPressed: openAppSettings,
                        child: const Text('Camera settings'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  _hint ??
                      'Point the camera at the customer’s voucher QR. You will review its details before redeeming.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Enter code instead'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
