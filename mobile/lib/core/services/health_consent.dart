import 'package:url_launcher/url_launcher.dart';
import '../config/env_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthConsent {
  static const key = 'stepsy_step_data_consent_v1';
  static Future<bool> hasConsent() async =>
      (await SharedPreferences.getInstance()).getBool(key) == true;

  static Future<bool> request(BuildContext context) async {
    if (await hasConsent()) return true;
    if (!context.mounted) return false;
    final accepted =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Step tracking & rewards'),
            content: const SingleChildScrollView(
              child: Text(
                'Stepsy reads your step count from your phone sensor and, when allowed, Health Connect or Apple Health. '
                'Your daily step total, date, and source are sent to our server to calculate points and show activity history and leaderboards. '
                'Background step counting uses a persistent notification with pause controls and may run when the app is closed, subject to phone settings. '
                'We do not send your step history to the AI helper. AI receives only a question you choose to submit. '
                'You can decline, revoke permissions in your phone settings, or delete your account in Profile.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(EnvConfig.privacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Privacy policy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Agree & continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (accepted) {
      await (await SharedPreferences.getInstance()).setBool(key, true);
    }
    return accepted;
  }
}
