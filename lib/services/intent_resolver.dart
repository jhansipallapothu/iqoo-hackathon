// Pure Dart — no Flutter imports, so `dart run` can execute the self-check.
//
// Resolves a spoken phrase ("open watsapp", "the maps app") to an installed
// package name. The inventory is the phone's real launchable-app list (label +
// package), fetched once from the platform side — no hand-maintained package
// map, so it works for every app the user actually has.

class AppEntry {
  final String label; // lowercased display label, e.g. "whatsapp"
  final String package;
  const AppEntry(this.label, this.package);
}

class IntentResolver {
  static List<AppEntry> _apps = const [];

  static bool get isEmpty => _apps.isEmpty;

  /// Feed the launchable-app list from the platform. Labels are lowercased here.
  static void setInventory(Iterable<AppEntry> apps) {
    _apps = [
      for (final a in apps) AppEntry(a.label.toLowerCase().trim(), a.package),
    ];
  }

  /// Best package for [spoken], or null if nothing clears the confidence bar.
  static String? resolvePackage(String spoken) => resolve(spoken)?.package;

  /// Best [AppEntry] for [spoken] — carries the real label for a spoken reply.
  static AppEntry? resolve(String spoken) {
    final q = spoken
        .toLowerCase()
        .replaceAll(RegExp(r'\b(the|my|an?|open|launch|start|go to)\b'), '')
        .replaceAll(RegExp(r'\bapp\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (q.isEmpty || _apps.isEmpty) return null;

    // Exact label, then substring either way — cheap and almost always right.
    for (final a in _apps) {
      if (a.label == q) return a;
    }
    for (final a in _apps) {
      if (a.label.contains(q) || q.contains(a.label)) return a;
    }

    // Fuzzy fallback for mis-hearings ("watsapp" -> "whatsapp").
    AppEntry? best;
    var score = 0.0;
    for (final a in _apps) {
      final r = _dice(q, a.label);
      if (r > score) {
        score = r;
        best = a;
      }
    }
    return (score >= 0.5) ? best : null;
  }

  /// Sørensen–Dice coefficient over character bigrams. 0..1.
  static double _dice(String a, String b) {
    if (a == b) return 1;
    if (a.length < 2 || b.length < 2) return 0;
    final bg = <String>[];
    for (var i = 0; i < b.length - 1; i++) {
      bg.add(b.substring(i, i + 2));
    }
    var hits = 0;
    for (var i = 0; i < a.length - 1; i++) {
      final pair = a.substring(i, i + 2);
      final j = bg.indexOf(pair);
      if (j >= 0) {
        hits++;
        bg[j] = ''; // consume, so repeats don't double-count
      }
    }
    return 2.0 * hits / (a.length - 1 + b.length - 1);
  }
}

/// Run: `dart run --enable-asserts lib/services/intent_resolver.dart`
/// (plain `dart run` does NOT execute `assert`s).
void main() {
  IntentResolver.setInventory(const [
    AppEntry('WhatsApp', 'com.whatsapp'),
    AppEntry('Gmail', 'com.google.android.gm'),
    AppEntry('Maps', 'com.google.android.apps.maps'),
    AppEntry('Phone', 'com.google.android.dialer'),
    AppEntry('Paytm', 'net.one97.paytm'),
  ]);

  // Exact + case-insensitive.
  assert(IntentResolver.resolvePackage('WhatsApp') == 'com.whatsapp');
  // Filler words stripped.
  assert(IntentResolver.resolvePackage('open the maps app') ==
      'com.google.android.apps.maps');
  // Mis-hearing, fuzzy match.
  assert(IntentResolver.resolvePackage('watsapp') == 'com.whatsapp');
  assert(IntentResolver.resolvePackage('gmaill') == 'com.google.android.gm');
  // Unknown app → null, never a wrong launch.
  assert(IntentResolver.resolvePackage('spotify') == null);
  assert(IntentResolver.resolvePackage('') == null);

  // Dice sanity.
  assert(IntentResolver._dice('whatsapp', 'whatsapp') == 1);
  assert(IntentResolver._dice('watsapp', 'whatsapp') > 0.7);
  assert(IntentResolver._dice('maps', 'gmail') < 0.3);

  print('intent_resolver: all checks passed');
}
