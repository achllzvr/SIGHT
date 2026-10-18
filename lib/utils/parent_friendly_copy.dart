/// Plain-language helpers for parent-facing clinical badges and labels.
class ParentFriendlyCopy {
  ParentFriendlyCopy._();

  static String conditionLabel(String? condition) {
    return switch (condition) {
      'SAFE' => 'Looking good',
      'CAUTION' => 'Worth watching',
      'AT_RISK' => 'Needs attention',
      'CRITICAL' => 'Talk to a doctor',
      _ => 'Checking…',
    };
  }

  static String trackLabel(String? status) => conditionLabel(status);

  static String blinkComfortLabel(int level) {
    return switch (level) {
      1 => 'Eyes look comfortable',
      2 => 'Blinking a bit less than ideal',
      3 => 'Eyes may feel dry — more blinks help',
      _ => 'Eyes need a break — try the blink game',
    };
  }

  static String usageBadgePlain(String? badge) {
    final b = (badge ?? '').toLowerCase();
    if (b.contains('optimal')) return 'Healthy amount';
    if (b.contains('within')) return "Within today's limit";
    if (b.contains('over-limit') || b.contains('mild')) return 'A little over the limit';
    if (b.contains('high')) return 'Well over the limit';
    if (b.contains('critical')) return 'Far over the limit — doctor visit advised';
    return badge ?? '—';
  }

  /// Soften server clinical prose for parent cards when still jargon-heavy.
  static String softenProse(String? text, {String fallback = ''}) {
    if (text == null || text.trim().isEmpty) return fallback;
    var out = text;
    const replacements = <String, String>{
      'OPI': 'eye comfort score',
      'tear-film': 'eye moisture',
      'Tear-film': 'Eye moisture',
      'Tear Film': 'Eye moisture',
      'accommodative': 'close-up eye strain',
      'Accommodative': 'Close-up eye strain',
      'myopia': 'nearsightedness risk',
      'Myopia': 'Nearsightedness risk',
      'dry-eye': 'dry eyes',
      'Dry-Eye': 'Dry eyes',
      'Dry Eye': 'Dry eyes',
      'telemetry': 'eye-care data',
      'IBI': 'time between blinks',
      'TBUT': 'eye moisture timing',
      'optometrist': 'eye doctor',
      'ophthalmologist': 'eye doctor',
    };
    replacements.forEach((from, to) {
      out = out.replaceAll(from, to);
    });
    return out;
  }
}
