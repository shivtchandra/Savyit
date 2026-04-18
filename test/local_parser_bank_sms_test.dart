import 'package:flutter_test/flutter_test.dart';
import 'package:money_lens/models/sms_candidate.dart';
import 'package:money_lens/services/local_parser_service.dart';

void main() {
  group('LocalParserService Axis UPI/P2M + SBI', () {
    test('Axis multiline INR + UPI/P2M merchant', () {
      const body = '''
INR 33.00 debited
A/c no. XX5089
09-04-26, 08:08:55
UPI/P2M/609955063377/ROPPEN TRANSPORTATI
Not you? SMS BLOCKUPI Cust ID to 919951860002
Axis Bank''';
      final t = LocalParserService.parseSms(
        SmsCandidate(smsId: 1, body: body, smsDate: DateTime(2026, 1, 1)),
      );
      expect(t, isNotNull);
      expect(t!.amount, 33.0);
      expect(t.merchant.toLowerCase(), contains('roppen'));
      expect(t.account, '5089');
      expect(t.bank, 'Axis');
      expect(t.date.month, 4);
      expect(t.date.day, 9);
    });

    test('Axis ZOMATO LIMITED', () {
      const body = '''
INR 309.28 debited
A/c no. XX5089
10-04-26, 20:11:50
UPI/P2M/153547358418/ZOMATO LIMITED
Not you? SMS BLOCKUPI Cust ID to 919951860002''';
      final t = LocalParserService.parseSms(
        SmsCandidate(smsId: 2, body: body, smsDate: null),
      );
      expect(t, isNotNull);
      expect(t!.amount, 309.28);
      expect(t.merchant.toLowerCase(), contains('zomato'));
    });

    test('SBI debited by … trf to Mr …', () {
      const body =
          'Dear UPI user A/C X4707 debited by 40.00 on date 09Apr26 trf to Mr Muthukumar R Refno 609914775933 If not u? call-1800111109 for other services-18001234-SBI';
      final t = LocalParserService.parseSms(
        SmsCandidate(smsId: 3, body: body, smsDate: null),
      );
      expect(t, isNotNull);
      expect(t!.amount, 40.0);
      expect(t.merchant.toLowerCase(), contains('muthukumar'));
      expect(t.account, '4707');
      expect(t.bank, 'SBI');
      expect(t.date.month, 4);
      expect(t.date.day, 9);
    });

    test('Generic Rs debited one line (before Avl Bal)', () {
      const body =
          'Rs.1,250.50 debited from A/c XX1234 on 15-Apr-26 to SWIGGY. Avl Bal Rs 50,000';
      final t = LocalParserService.parseSms(
        SmsCandidate(smsId: 40, body: body, smsDate: null),
      );
      expect(t, isNotNull);
      expect(t!.amount, 1250.50);
      expect(t.merchant.toLowerCase(), contains('swiggy'));
      expect(t.type, 'debit');
    });

    test('Paid Rs … to … (wallet-style)', () {
      const body = 'Paid Rs.99.00 to DOMINOS PIZZA on 02-Apr-26 via UPI Ref 123';
      final t = LocalParserService.parseSms(
        SmsCandidate(smsId: 41, body: body, smsDate: null),
      );
      expect(t, isNotNull);
      expect(t!.amount, 99.0);
      expect(t.merchant.toLowerCase(), contains('dominos'));
    });

    test('Fallback: debited … later Rs amount (non-P2M banks)', () {
      const body =
          'Your A/c XX5678 is debited for Rs 320.50 on 01-Apr-26 VPA zomato@paytm ZOMATO Ref 999';
      final t = LocalParserService.parseSms(
        SmsCandidate(smsId: 42, body: body, smsDate: null),
      );
      expect(t, isNotNull);
      expect(t!.amount, 320.50);
      expect(t.merchant.toLowerCase(), contains('zomato'));
    });
  });
}
