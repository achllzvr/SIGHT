/// Client-side mirrors of ClinicalAnalyticsService (age max, OPI, usage tiers).
/// Server remains authoritative for multi-horizon trend alerts.
class ClinicalAnalyticsHelpers {
  ClinicalAnalyticsHelpers._();

  static const double tbutSeconds = 6.0;

  /// Robust parse for API / local JSON birthdates (`YYYY-MM-DD` or ISO).
  static DateTime? parseBirthdate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    final dateOnly = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(s);
    if (dateOnly != null) {
      return DateTime.tryParse(dateOnly.group(1)!);
    }
    return DateTime.tryParse(s);
  }

  static int chronologicalAgeYears(DateTime? birthdate, {DateTime? now}) {
    if (birthdate == null) return 12;
    final n = now ?? DateTime.now();
    var age = n.year - birthdate.year;
    if (n.month < birthdate.month ||
        (n.month == birthdate.month && n.day < birthdate.day)) {
      age--;
    }
    return age.clamp(0, 120);
  }

  /// Parent-list age label — never shows "0 years old" for missing birthdates.
  static String ageDisplayLabel(DateTime? birthdate, {DateTime? now}) {
    if (birthdate == null) return 'Birthdate needed';
    final n = now ?? DateTime.now();
    var age = n.year - birthdate.year;
    if (n.month < birthdate.month ||
        (n.month == birthdate.month && n.day < birthdate.day)) {
      age--;
    }
    if (age < 1) return 'Under 1 year';
    return '$age years old';
  }

  /// Ages 3–5 → 60, 6–8 → 90, 9–12+ → 120.
  static int ageMaxMinutes(int ageYears) {
    if (ageYears <= 5) return 60;
    if (ageYears <= 8) return 90;
    return 120;
  }

  static int clampDailyLimit(int requested, int ageMax) {
    return requested.clamp(15, ageMax);
  }

  static Map<String, dynamic> interpretUsageThreshold(double actualMinutes, int ageMax) {
    final max = ageMax <= 0 ? 120 : ageMax;
    final percent = (actualMinutes / max) * 100.0;
    if (percent <= 50) {
      return {
        'tier': 1,
        'key': 'optimal',
        'badge': 'Healthy amount',
        'label': 'Healthy amount of screen time for this age',
        'percent': percent,
      };
    }
    if (percent <= 100) {
      return {
        'tier': 2,
        'key': 'allowable',
        'badge': "Within today's limit",
        'label': "Within today's screen-time limit",
        'percent': percent,
      };
    }
    if (percent <= 125) {
      return {
        'tier': 3,
        'key': 'mild_over',
        'badge': 'A little over the limit',
        'label': 'A little past the daily limit — eyes may feel tired',
        'percent': percent,
      };
    }
    if (percent <= 150) {
      return {
        'tier': 4,
        'key': 'high_over',
        'badge': 'Well over the limit',
        'label': 'Well past the daily limit — take longer breaks',
        'percent': percent,
      };
    }
    return {
      'tier': 5,
      'key': 'critical_over',
      'badge': 'Far over the limit — doctor visit advised',
      'label': 'Far past the daily limit — please check with an eye doctor',
      'percent': percent,
    };
  }

  /// Ousler OPI = TBUT / IBI; IBI = 60 / blinkRate.
  static Map<String, dynamic> calculateOcularProtectionIndex(double blinkRate) {
    if (blinkRate <= 0) {
      return {
        'blink_rate': blinkRate,
        'ibi_seconds': null,
        'opi': null,
        'level': 4,
        'label': 'Eyes need a break — try the blink game',
      };
    }
    final ibi = 60.0 / blinkRate;
    final opi = tbutSeconds / ibi;
    late int level;
    late String label;
    if (blinkRate >= 12 && opi >= 1.20) {
      level = 1;
      label = 'Eyes look comfortable';
    } else if (blinkRate >= 10 && opi >= 1.00) {
      level = 2;
      label = 'Blinking a bit less than ideal';
    } else if (blinkRate >= 6 && opi >= 0.60) {
      level = 3;
      label = 'Eyes may feel dry — more blinks help';
    } else {
      level = 4;
      label = 'Eyes need a break — try the blink game';
    }
    return {
      'blink_rate': blinkRate,
      'ibi_seconds': ibi,
      'opi': opi,
      'level': level,
      'label': label,
    };
  }

  static const rangeOptions = <({String api, String label})>[
    (api: '7d', label: 'Last 7 Days'),
    (api: '30d', label: 'Last Month'),
    (api: '90d', label: 'Last 3 Months'),
    (api: '180d', label: 'Last 6 Months'),
    (api: '365d', label: 'Last Year'),
    (api: 'lifetime', label: 'Lifetime'),
  ];

  static Duration lookbackForRange(String api) {
    return switch (api) {
      '30d' => const Duration(days: 30),
      '90d' => const Duration(days: 90),
      '180d' => const Duration(days: 180),
      '365d' => const Duration(days: 365),
      'lifetime' => const Duration(days: 3650),
      _ => const Duration(days: 7),
    };
  }
}
