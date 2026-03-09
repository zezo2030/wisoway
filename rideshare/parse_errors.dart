import 'dart:io';
import 'dart:convert';

void main() {
  final file = File(
    'C:/Users/HP/.gemini/antigravity/brain/f2e1dad8-ff37-416c-bf70-4b745ac1d0e7/.system_generated/steps/486/output.txt',
  );
  if (!file.existsSync()) {
    print('No errors file found.');
    return;
  }

  final lines = file.readAsLinesSync();
  int count = 0;
  List<String> errors = [];

  for (var line in lines) {
    if (line.trim().isEmpty || !line.contains('{"code"')) continue;
    try {
      final startIndex = line.indexOf('{');
      final jsonStr = line.substring(startIndex);
      final data = jsonDecode(jsonStr);
      if (data['severity'] == 1) {
        final uri = data['uri'].toString().replaceAll(
          'file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/',
          '',
        );
        final lineNum = data['range']['start']['line'] + 1; // 1-based logic
        final msg = data['message'];
        errors.add('- $uri:$lineNum -> $msg');
        count++;
      }
    } catch (e) {
      // Ignore parse errors for split lines
    }
  }

  final outFile = File('critical_errors.txt');
  final sb = StringBuffer();
  sb.writeln('Found $count Critical Errors:');
  for (var e in errors) {
    sb.writeln(e);
  }
  outFile.writeAsStringSync(sb.toString());
}
