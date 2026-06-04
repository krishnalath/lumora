import 'dart:io';
void main() {
  final file = File('lib/screens/therapist_dashboard_screen.dart');
  final lines = file.readAsLinesSync();
  lines.removeRange(651, 800);
  file.writeAsStringSync(lines.join('\n'));
}
