import 'dart:io';

void main() {
  final file = File('issues.json');
  if (!file.existsSync()) {
    print('No issues file found.');
    return;
  }
  final lines = file.readAsLinesSync();
  int count = 0;
  for (var line in lines) {
    if (line.contains('ERROR|')) {
      final parts = line.split('|');
      if (parts.length > 7) {
        final severity = parts[0];
        final type = parts[1];
        final errCode = parts[2];
        final file = parts[3];
        final lineNum = parts[4];
        final msg = parts[7];
        print('ERROR in $file:$lineNum - $msg');
        count++;
      }
    }
  }
  print('Total Errors: $count');
}
