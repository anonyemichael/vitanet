import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File(r'C:\Users\atubt\.gemini\antigravity-ide\brain\a5e64f32-b784-43b5-986d-04c80d6723ff\.system_generated\logs\transcript.jsonl');
  final lines = await file.readAsLines();
  for (final line in lines) {
    try {
      final data = jsonDecode(line);
      final step = data['step_index'] as int;
      if (step >= 2390 && step <= 2395 && data['source'] == 'MODEL') {
        var msg = data['content'] as String?;
        if (msg != null) {
          print('Step ${step}:\n${msg}\n-------------------');
        }
      }
    } catch (e) {}
  }
}
