// lib/utils/money_format.dart
// Compact money strings (K / L / Cr) with a caller-supplied currency symbol.

String formatMoneyAmount(
  double val,
  String currencySymbol, {
  bool showSign = false,
}) {
  final isNeg = val < 0;
  final v = val.abs();
  String formatted;
  if (v >= 10000000) {
    formatted = '$currencySymbol${(v / 10000000).toStringAsFixed(1)}Cr';
  } else if (v >= 100000) {
    formatted = '$currencySymbol${(v / 100000).toStringAsFixed(1)}L';
  } else if (v >= 1000) {
    formatted = '$currencySymbol${(v / 1000).toStringAsFixed(1)}K';
  } else {
    formatted = '$currencySymbol${v.toStringAsFixed(0)}';
  }
  if (isNeg) return '-$formatted';
  if (showSign && val > 0) return '+$formatted';
  return formatted;
}
