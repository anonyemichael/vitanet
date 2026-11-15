import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Resolves a stored profile image path (local file or URL) to an image.
ImageProvider? profileImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return NetworkImage(path);
  if (kIsWeb) return null;
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    return FileImage(file);
  } catch (_) {
    return null;
  }
}
