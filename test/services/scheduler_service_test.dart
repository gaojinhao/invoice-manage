import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/services/scheduler_service.dart';

void main() {
  group('SchedulerService.nextRunAt', () {
    test('returns duration until target time today when in the future', () {
      final svc = SchedulerService();
      // Freeze time at 08:00, target 10:00 → should be 2 hours
      final now = DateTime(2026, 6, 11, 8, 0, 0);
      final delay = svc.nextRunAt(10, 0, now: now);
      expect(delay, const Duration(hours: 2));
    });

    test('returns duration until target time tomorrow when already passed', () {
      final svc = SchedulerService();
      // Freeze time at 14:00, target 10:00 → should be 20 hours (next day)
      final now = DateTime(2026, 6, 11, 14, 0, 0);
      final delay = svc.nextRunAt(10, 0, now: now);
      expect(delay, const Duration(hours: 20));
    });

    test('returns zero when exactly at target time', () {
      final svc = SchedulerService();
      final now = DateTime(2026, 6, 11, 10, 0, 0);
      final delay = svc.nextRunAt(10, 0, now: now);
      // next.isBefore(now) is false when equal, so delay is 0
      expect(delay, Duration.zero);
    });

    test('handles minute-level precision', () {
      final svc = SchedulerService();
      // 1 minute before target
      final now = DateTime(2026, 6, 11, 9, 59, 0);
      final delay = svc.nextRunAt(10, 0, now: now);
      expect(delay, const Duration(minutes: 1));
    });

    test('handles midnight wrap: target at 00:30, now at 23:00', () {
      final svc = SchedulerService();
      final now = DateTime(2026, 6, 11, 23, 0, 0);
      final delay = svc.nextRunAt(0, 30, now: now);
      expect(delay, const Duration(hours: 1, minutes: 30));
    });

    test('handles month boundary', () {
      final svc = SchedulerService();
      // Last day of month, target already passed
      final now = DateTime(2026, 6, 30, 12, 0, 0);
      final delay = svc.nextRunAt(10, 0, now: now);
      // Next day wraps to July 1
      expect(delay, const Duration(hours: 22));
    });

    test('handles year boundary (Dec 31 → Jan 1)', () {
      final svc = SchedulerService();
      final now = DateTime(2026, 12, 31, 23, 0, 0);
      final delay = svc.nextRunAt(0, 30, now: now);
      // 1.5 hours from 23:00 to 00:30 next day (Jan 1 2027)
      expect(delay, const Duration(hours: 1, minutes: 30));
    });
  });

  group('SchedulerService.nextMonthlyRun', () {
    test('returns delay until next month 1st 08:00 from mid-month', () {
      final svc = SchedulerService();
      // June 15 → July 1 08:00
      final now = DateTime(2026, 6, 15, 12, 0, 0);
      final delay = svc.nextMonthlyRun(now: now);
      // 16 days from June 15 12:00 to July 1 08:00
      final expected = DateTime(2026, 7, 1, 8, 0, 0).difference(now);
      expect(delay, expected);
    });

    test('returns delay until today 08:00 when on 1st before 8 AM', () {
      final svc = SchedulerService();
      // June 1 at 06:00 → June 1 08:00 (today)
      final now = DateTime(2026, 6, 1, 6, 0, 0);
      final delay = svc.nextMonthlyRun(now: now);
      expect(delay, const Duration(hours: 2));
    });

    test('returns delay until next month when on 1st after 8 AM', () {
      final svc = SchedulerService();
      // June 1 at 10:00 → July 1 08:00
      final now = DateTime(2026, 6, 1, 10, 0, 0);
      final delay = svc.nextMonthlyRun(now: now);
      final expected = DateTime(2026, 7, 1, 8, 0, 0).difference(now);
      expect(delay, expected);
    });

    test('returns delay until next month when on 1st exactly at 08:00', () {
      final svc = SchedulerService();
      // June 1 at 08:00 exactly → July 1 08:00
      // hour < 8 is false, so goes to next month
      final now = DateTime(2026, 6, 1, 8, 0, 0);
      final delay = svc.nextMonthlyRun(now: now);
      final expected = DateTime(2026, 7, 1, 8, 0, 0).difference(now);
      expect(delay, expected);
    });

    test('handles December → January wrap', () {
      final svc = SchedulerService();
      // Dec 15 → Jan 1 08:00 of next year
      final now = DateTime(2026, 12, 15, 12, 0, 0);
      final delay = svc.nextMonthlyRun(now: now);
      final expected = DateTime(2027, 1, 1, 8, 0, 0).difference(now);
      expect(delay, expected);
    });

    test('returns delay until next month from last day of month', () {
      final svc = SchedulerService();
      // June 30 → July 1 08:00
      final now = DateTime(2026, 6, 30, 23, 0, 0);
      final delay = svc.nextMonthlyRun(now: now);
      final expected = DateTime(2026, 7, 1, 8, 0, 0).difference(now);
      expect(delay, expected);
    });

    test('defaults to DateTime.now() when no now parameter', () {
      final svc = SchedulerService();
      final delay = svc.nextMonthlyRun();
      // Just verify it returns a non-negative Duration
      expect(delay.inMilliseconds >= 0, isTrue);
      // Should be less than 32 days worth of milliseconds
      expect(delay.inDays < 32, isTrue);
    });

    test('defaults to DateTime.now() for nextRunAt', () {
      final svc = SchedulerService();
      final delay = svc.nextRunAt(10, 0);
      // Just verify it returns a non-negative Duration
      expect(delay.inMilliseconds >= 0, isTrue);
      // Should be less than 24 hours
      expect(delay.inHours < 24, isTrue);
    });
  });
}
