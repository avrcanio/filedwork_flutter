// Semver usporedba za provjeru verzije app-a.

int compareSemver(String left, String right) {
  List<int> parse(String value) {
    final core = value.split('+').first.trim();
    final parts = core.split('.');
    return [
      _parsePart(parts, 0),
      _parsePart(parts, 1),
      _parsePart(parts, 2),
    ];
  }

  final a = parse(left);
  final b = parse(right);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

int _parsePart(List<String> parts, int index) {
  if (index >= parts.length) return 0;
  return int.tryParse(parts[index]) ?? 0;
}

bool isVersionOlder(String current, String target) =>
    compareSemver(current, target) < 0;
