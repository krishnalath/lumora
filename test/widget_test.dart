import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/sleep_record.dart';

void main() {
  test('SleepRecord score calculations', () {
    // 8-hour sleep duration (within 7-9h optimal range)
    final recordExcellent = SleepRecord(
      id: '1',
      sleepStart: DateTime(2026, 6, 4, 22, 0),
      sleepEnd: DateTime(2026, 6, 5, 6, 0),
    );

    expect(recordExcellent.duration.inHours, 8);
    expect(recordExcellent.sleepScore, 100); // 70 base + 30 bonus
    expect(recordExcellent.qualityLabel, 'Excellent');

    // 4-hour sleep duration (outside optimal/suboptimal ranges)
    final recordPoor = SleepRecord(
      id: '2',
      sleepStart: DateTime(2026, 6, 4, 22, 0),
      sleepEnd: DateTime(2026, 6, 5, 2, 0),
    );

    expect(recordPoor.duration.inHours, 4);
    expect(recordPoor.sleepScore, 70); // 70 base + 0 bonus
    expect(recordPoor.qualityLabel, 'Good'); // 70 is marked as Good
  });
}
