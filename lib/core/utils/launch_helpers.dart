import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helpers for opening phone dialer and maps from VitaNet features.
class LaunchHelpers {
  LaunchHelpers._();

  static Future<bool> dial(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri);
  }

  static Future<bool> openPharmacySearch([String query = 'pharmacy near me']) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> dialOrSnack(BuildContext context, String number) async {
    final ok = await dial(number);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open dialer for $number')),
      );
    }
  }

  static Future<void> openPharmacyOrSnack(
    BuildContext context, [
    String query = 'pharmacy near me',
  ]) async {
    final ok = await openPharmacySearch(query);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps')),
      );
    }
  }
}
