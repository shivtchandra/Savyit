
import 'dart:convert';
import 'dart:io';
import '../lib/models/sms_candidate.dart';
import '../lib/models/transaction.dart';
import '../lib/services/local_parser_service.dart';

void main() async {
  final file = File('data/kaggle_indian_bank_sms_dataset.jsonl');
  if (!file.existsSync()) {
    print('Error: data/kaggle_indian_bank_sms_dataset.jsonl not found.');
    return;
  }

  final lines = await file.readAsLines();
  int totalFin = 0;
  int parsedCount = 0;
  int amountMismatches = 0;
  final failingSms = <Map<String, dynamic>>[];

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final row = jsonDecode(line);
    
    // Only audit financial transactions that are not "synthetic_spin" (standard bank templates)
    if (row['is_financial_transaction'] != 1) continue;
    if (row['label_category'] == 'synthetic_spin') continue;
    
    totalFin++;
    final rawSms = row['raw_sms'];
    final expectedAmount = (row['amount'] as num).toDouble();

    final txn = LocalParserService.parseSms(
      SmsCandidate(smsId: 0, body: rawSms, smsDate: null),
    );

    if (txn == null) {
      failingSms.add({
        'id': row['id'],
        'sms': rawSms,
        'reason': 'NULL_PARSED',
        'expected_amount': expectedAmount,
      });
    } else {
      parsedCount++;
      if ((txn.amount - expectedAmount).abs() > 0.01) {
        amountMismatches++;
        failingSms.add({
          'id': row['id'],
          'sms': rawSms,
          'reason': 'AMOUNT_MISMATCH',
          'expected_amount': expectedAmount,
          'got_amount': txn.amount,
        });
      }
    }
  }

  print('\n=== PARSER AUDIT RESULTS ===');
  print('Total Financial SMS evaluated: $totalFin');
  print('Successfully parsed: $parsedCount (${(parsedCount/totalFin*100).toStringAsFixed(1)}%)');
  print('Amount Mismatches: $amountMismatches');
  print('Total Failures: ${failingSms.length}');
  print('============================\n');

  if (failingSms.isNotEmpty) {
    print('Top failing examples:');
    final limit = failingSms.length > 10 ? 10 : failingSms.length;
    for (int i = 0; i < limit; i++) {
        final f = failingSms[i];
        print('[${f['reason']}] ID: ${f['id']}');
        print('SMS: ${f['sms']}');
        print('Expected: ${f['expected_amount']}${f['got_amount'] != null ? ' Got: ${f['got_amount']}' : ''}');
        print('---');
    }
  }
}
