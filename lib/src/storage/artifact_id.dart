/// Returns a safe Walki artifact ID, or `null` if [raw] is unsafe.
String? normalizeArtifactId(String raw) {
  final value = raw.trim();
  if (value.isEmpty ||
      value != raw ||
      value.contains('..') ||
      !_artifactIdPattern.hasMatch(value)) {
    return null;
  }
  return value;
}

final _artifactIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');
