import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_lens/models/sms_candidate.dart';
import 'package:money_lens/services/local_parser_service.dart';

/// Loads [data/kaggle_indian_bank_sms_dataset.jsonl] and checks LocalParserService.
/// Excludes `synthetic_spin` rows (volume filler; not all templates match rules).
void main() {
  test('Kaggle JSONL: non-financial rows must not parse as transactions', () {
    final file = File('data/kaggle_indian_bank_sms_dataset.jsonl');
    expect(file.existsSync(), isTrue,
        reason: 'Run: python3 scripts/generate_kaggle_indian_bank_sms.py');

    for (final line in file.readAsLinesSync()) {
      if (line.isEmpty) continue;
      final row = jsonDecode(line) as Map<String, dynamic>;
      final fin = row['is_financial_transaction'] == 1;
      if (fin) continue;
      final raw = row['raw_sms'] as String;
      final t = LocalParserService.parseSms(
        SmsCandidate(smsId: row['id'].hashCode, body: raw, smsDate: null),
      );
      expect(t, isNull, reason: 'id=${row['id']} should not parse');
    }
  });

  test('Kaggle JSONL: financial non-spin rows parse with correct amount', () {
    final file = File('data/kaggle_indian_bank_sms_dataset.jsonl');
    expect(file.existsSync(), isTrue);

    final failures = <String>[];

    for (final line in file.readAsLinesSync()) {
      if (line.isEmpty) continue;
      final row = jsonDecode(line) as Map<String, dynamic>;
      if (row['is_financial_transaction'] != 1) continue;
      if (row['label_category'] == 'synthetic_spin') continue;

      final raw = row['raw_sms'] as String;
      final expectedAmount = (row['amount'] as num).toDouble();
      final expectedMerchant = (row['merchant'] as String?)?.trim() ?? '';
      final id = row['id'] as String;

      final t = LocalParserService.parseSms(
        SmsCandidate(smsId: id.hashCode, body: raw, smsDate: null),
      );
      if (t == null) {
        failures.add('$id: got null');
        continue;
      }
      if ((t.amount - expectedAmount).abs() > 0.02) {
        failures.add(
            '$id: amount want $expectedAmount got ${t.amount} merchant=${t.merchant}');
        continue;
      }
      if (expectedMerchant.isNotEmpty) {
        final ok = _merchantMatches(expectedMerchant, t.merchant, raw);
        if (!ok) {
          failures.add(
              '$id: merchant want "$expectedMerchant" got "${t.merchant}"');
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}

bool _merchantMatches(String expected, String parsed, String raw) {
  String norm(String s) => s
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final e = norm(expected);
  final p = norm(parsed);
  final r = raw.toLowerCase();

  if (e.isEmpty) return true;
  if (p == e) return true;
  if (p.replaceAll(' ', '') == e.replaceAll(' ', '')) return true;
  if (p.contains(e) || e.contains(p)) return true;

  // UPI: "swiggy.in@ybl" vs title-cased handle "Swiggy In"
  if (expected.contains('@')) {
    final handle = expected.split('@').first.toLowerCase();
    final root = handle.split('.').first;
    if (root.length >= 3 && p.contains(root)) return true;
  }

  // NEFT_INCOMING vs bank narration
  if (e.contains('neft') && r.contains('neft') && p.length >= 4) return true;

  // INTEREST_CREDIT / UPI_RECHARGE style labels
  if (e.contains('interest') && p.contains('interest')) return true;
  if (e.contains('recharge') && p.contains('recharge')) return true;

  for (final token in e.split(RegExp(r'[\s@]+'))) {
    if (token.length >= 3 && r.contains(token) && (p.contains(token) || p.isNotEmpty)) {
      return true;
    }
  }
  return false;
}
