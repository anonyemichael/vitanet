// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File(r'transcript.jsonl');
  if (!file.existsSync()) return;
  final lines = await file.readAsLines();
  for (final line in lines) {
    try {
      final data = jsonDecode(line);
      final step = data['step_index'] as int;
      if (step >= 2390 && step <= 2395 && data['source'] == 'MODEL') {
        var msg = data['content'] as String?;
        if (msg != null) {
          print('Step $step:\n$msg\n-------------------');
        }
      }
    } catch (_) {
      // Ignore malformed JSON lines
    }
  }
}
