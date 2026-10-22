/// Normalizes an Indian phone number to a bare local-format digit string
/// so two differently-formatted representations of the same number compare
/// equal. Replaces the `dialer-version` branch's placeholder `endsWith`
/// suffix match (explicitly flagged in that branch's own code comments as
/// "not production-grade") with real full-equality comparison — a bare
/// suffix match can silently cross-match unrelated numbers that happen to
/// share a trailing run of digits.
///
/// Handles:
///   +91 98765 43210  -> 9876543210
///   919876543210     -> 9876543210
///   09876543210      -> 9876543210
///   9876543210       -> 9876543210
///
/// This is intentionally a light, dependency-free normalizer scoped to the
/// country codes this org actually operates in, not a full libphonenumber
/// integration — if international numbers become a real requirement, swap
/// this for a proper phone-number library rather than hand-rolling more
/// prefix rules here.
String normalizePhoneNumber(String raw) {
  // Strip every non-digit character (including the leading '+', if any —
  // what's left is just the digit string, e.g. "+91 98765 43210" -> "9198765..." ).
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

  if (digits.startsWith('91') && digits.length == 12) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0') && digits.length == 11) {
    digits = digits.substring(1);
  }

  return digits;
}

/// Below this length, a normalized number is too short to trust as a real
/// match key — guards [phoneNumbersMatch] against false positives on
/// garbage/partial input, not against the comparison itself (which is
/// always full equality, never a suffix match).
const int kMinNormalizedPhoneLength = 7;

bool phoneNumbersMatch(String a, String b) {
  final na = normalizePhoneNumber(a);
  final nb = normalizePhoneNumber(b);
  if (na.length < kMinNormalizedPhoneLength || nb.length < kMinNormalizedPhoneLength) {
    return false;
  }
  return na == nb;
}
