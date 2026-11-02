import 'dart:io';

/// Automated Asset Downloader for VitaNet
/// Downloads all remote Unsplash images locally to assets/images/clinical/
/// to enable instantaneous offline rendering and eliminate network lag.

final Map<String, String> imageCatalog = {
  // Emergency CPR & Resuscitation
  'cpr_resuscitation.jpg':
      'https://images.unsplash.com/photo-1516549655169-df83a0774514?auto=format&fit=crop&w=900&q=80',
  'first_responders.jpg':
      'https://images.unsplash.com/photo-1584515933487-779824d29309?auto=format&fit=crop&w=900&q=80',
  'emergency_response.jpg':
      'https://images.unsplash.com/photo-1579684385127-1ef15d508118?auto=format&fit=crop&w=900&q=80',
  'emergency_kit.jpg':
      'https://images.unsplash.com/photo-1532938911079-1b06ac7ceec7?auto=format&fit=crop&w=900&q=80',

  // First Aid & Trauma Care
  'sterile_supplies.jpg':
      'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=900&q=80',
  'bandage_therapy.jpg':
      'https://images.unsplash.com/photo-1588776814546-1ffcf47267a5?auto=format&fit=crop&w=900&q=80',
  'wound_care.jpg':
      'https://images.unsplash.com/photo-1584516150909-c43483ee7932?auto=format&fit=crop&w=900&q=80',
  'clinical_recovery.jpg':
      'https://images.unsplash.com/photo-1584362917165-526a968579e8?auto=format&fit=crop&w=900&q=80',
  'cuts_scrapes.jpg':
      'https://images.unsplash.com/photo-1603398938378-e54eab446dde?auto=format&fit=crop&w=900&q=80',
  'first_aid_kit.jpg':
      'https://images.unsplash.com/photo-1530497610245-94d3c16cda28?auto=format&fit=crop&w=900&q=80',

  // Medical Clinical Diagnostics
  'stethoscope_diagnostics.jpg':
      'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=900&q=80',
  'clinical_examination.jpg':
      'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?auto=format&fit=crop&w=900&q=80',
  'hospital_care.jpg':
      'https://images.unsplash.com/photo-1631815589968-fdb09a223b1e?auto=format&fit=crop&w=900&q=80',
  'cardiology_ecg.jpg':
      'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=900&q=80',

  // Wellness & Lifestyle
  'fitness_vitality.jpg':
      'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&w=900&q=80',
  'mindfulness_wellness.jpg':
      'https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=900&q=80',
  'balanced_nutrition.jpg':
      'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=900&q=80',
  'health_balance.jpg':
      'https://images.unsplash.com/photo-1526256262350-7da7584cf5eb?auto=format&fit=crop&w=900&q=80',

  // AI & Digital Health
  'ai_tech.jpg':
      'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=900&q=80',
  'digital_health.jpg':
      'https://images.unsplash.com/photo-1531403009284-440f080d1e12?auto=format&fit=crop&w=900&q=80',

  // Clinician Avatars
  'avatar_female_clinician.jpg':
      'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&w=400&q=80',
  'avatar_male_physician.jpg':
      'https://images.unsplash.com/photo-1622253692010-333f2da6031d?auto=format&fit=crop&w=400&q=80',
  'avatar_doctor_portrait.jpg':
      'https://images.unsplash.com/photo-1537368910025-700350fe46c7?auto=format&fit=crop&w=400&q=80',

  // Clinical Research Articles Specific
  'metabolic_nutrition.jpg':
      'https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=800&q=80',
  'circadian_sleep.jpg':
      'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?auto=format&fit=crop&w=800&q=80',
  'hydration_health.jpg':
      'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80',
  'glucose_monitoring.jpg':
      'https://images.unsplash.com/photo-1434493789847-2f02dc6ca35d?auto=format&fit=crop&w=800&q=80',
  'respiratory_health.jpg':
      'https://images.unsplash.com/photo-1584017911766-d451b3d0e843?auto=format&fit=crop&w=800&q=80',
  'pharmaceutical_pills.jpg':
      'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?auto=format&fit=crop&w=800&q=80',
  'medicine_detail_hero.jpg':
      'https://images.unsplash.com/photo-1576602976047-174e57a47881?auto=format&fit=crop&w=800&q=80',
};

Future<void> main() async {
  final targetDir = Directory('assets/images/clinical');
  if (!targetDir.existsSync()) {
    targetDir.createSync(recursive: true);
    print('Created directory: ${targetDir.path}');
  }

  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  client.userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  print('Starting download of ${imageCatalog.length} clinical assets...');
  int successCount = 0;
  int failCount = 0;

  for (final entry in imageCatalog.entries) {
    final filename = entry.key;
    final url = entry.value;
    final file = File('${targetDir.path}/$filename');

    if (file.existsSync() && file.lengthSync() > 1000) {
      print(' [EXISTS] $filename (${file.lengthSync()} bytes) - Skipping');
      successCount++;
      continue;
    }

    print(' [DOWNLOADING] $filename from $url');
    bool downloaded = false;

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set(
            HttpHeaders.acceptHeader, 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8');
        final response = await request.close();

        if (response.statusCode == 200) {
          final bytes = <int>[];
          await for (final chunk in response) {
            bytes.addAll(chunk);
          }
          await file.writeAsBytes(bytes);
          print('   ✓ Saved $filename (${bytes.length} bytes)');
          downloaded = true;
          successCount++;
          break;
        } else if (response.statusCode == 301 || response.statusCode == 302) {
          final redirectUrl = response.headers.value(HttpHeaders.locationHeader);
          if (redirectUrl != null) {
            final redirReq = await client.getUrl(Uri.parse(redirectUrl));
            final redirRes = await redirReq.close();
            if (redirRes.statusCode == 200) {
              final bytes = <int>[];
              await for (final chunk in redirRes) {
                bytes.addAll(chunk);
              }
              await file.writeAsBytes(bytes);
              print('   ✓ Saved (via redirect) $filename (${bytes.length} bytes)');
              downloaded = true;
              successCount++;
              break;
            }
          }
        } else {
          print('   Attempt $attempt failed: HTTP status ${response.statusCode}');
        }
      } catch (e) {
        print('   Attempt $attempt error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!downloaded) {
      print('   ✗ FAILED to download $filename');
      failCount++;
    }
  }

  client.close();
  print('\nDownload Summary: $successCount succeeded, $failCount failed.');
}
