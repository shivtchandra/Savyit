// lib/services/sms_service.dart
// Phase 1: read SMS + pre-filter for financial candidates
// Phase 2: classification is OpenAI-only (see TransactionProvider.load + OpenAIService).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sms_candidate.dart';

// ─── SECTORS (kept for UI display) ───────────────────────────────────────
class Sector {
  final String name;
  final String icon;
  const Sector(this.name, this.icon);
}

const sectors = [
  Sector('Food & Dining',     ''),
  Sector('Transport',         ''),
  Sector('Shopping',          ''),
  Sector('Health',            ''),
  Sector('Entertainment',     ''),
  Sector('Utilities & Bills', ''),
  Sector('Transfer',          ''),
  Sector('Other',             ''),
];

Sector getSector(String name) =>
    sectors.firstWhere((s) => s.name == name, orElse: () => sectors.last);

// ─── Pre-filter: catches anything that MIGHT be financial ────────────────
final _finKeywords = RegExp(
  r'\b(debit|credit|paid|spent|received|withdraw|purchas|payment|transfer|refund|cashback|salary|a\/c|acct|upi|neft|imps|rtgs|txn|tnx|transaction|debited|credited|amount\s+of|via|ref)\b',
  caseSensitive: false,
);
final _moneyRe = RegExp(
  r'(?:rs\.?|inr|₹|rupees)\s*[\d,]+(\.\d{1,2})?|(?:rs\.?|inr|₹)\s*\d+',
  caseSensitive: false,
);
final _hasAmount = RegExp(r'\d+(\.\d{2})?'); // e.g. 46, 46.00, 1500

// ─── Exclusion filter: known ad/promotional patterns ─────────────────────
// Catches marketing messages that mention money but are NOT real transactions.
final _promoKeywords = RegExp(
  r'\b(flat\s+\d+%\s+off|use\s+code|shop\s+now|sale\s+now|deal|offer|coupon|discount|cashback\s+offer|get\s+\d+%|sign[\s-]?up|download\s+(the\s+)?app|install[\s\w]+app|exclusive\s+offer|limited[\s-]?time|hurry|don.?t\s+miss|unlock\s+(your|upto|up\s+to)|win\s+|gift\s+voucher|gift\s+card|promo|click\s+here|tap\s+here|visit\s+|order\s+now|explore\s+now|check\s+out|new\s+arrival|free\s+delivery|reward\s+point)',
  caseSensitive: false,
);
// Well-known e-commerce/retail brands that send spam offers
final _promoSenders = RegExp(
  r'\b(snitch|myntra|amazon|flipkart|meesho|ajio|nykaa|blinkit|swiggy\s+instamart|zomato\s+(discount|offer|coupon)|zepto|bigbasket\s+offer|paytm\s+(offer|reward|cashback\s+offer)|phonepe\s+offer|instagram|whatsapp\s+business|olx|quikr|makemytrip\s+(offer|deal|coupon)|ixigo\s+(deal|offer)|cleartrip\s+(offer|deal))\b',
  caseSensitive: false,
);

bool _isFinancialCandidate(String body) {
  final bodyLower = body.toLowerCase();
  
  // Financial keywords that indicate this is likely a real transaction
  final hasAction = bodyLower.contains('debited') || 
                   bodyLower.contains('credited') || 
                   bodyLower.contains('spent') || 
                   bodyLower.contains('paid') || 
                   bodyLower.contains('received') ||
                   bodyLower.contains('txn') ||
                   bodyLower.contains('tnx') ||
                   bodyLower.contains('transfer') ||
                   bodyLower.contains('transaction');

  // First: reject known promotional messages, BUT only if they don't look like actual transactions
  if (_promoKeywords.hasMatch(body) && !hasAction) return false;
  if (_promoSenders.hasMatch(body) && !hasAction) return false;

  // Has a money keyword like Rs/INR/₹
  if (_moneyRe.hasMatch(body)) return true;
  
  // If no currency symbol, check for keyword + any 3-digit number (common in quick alerts)
  if (_finKeywords.hasMatch(body)) {
    if (RegExp(r'\d{3,}').hasMatch(body)) return true;
  }
  return false;
}

// ─── PUBLIC API ──────────────────────────────────────────────────────────
class SmsService {
  static final _query = SmsQuery();

  static Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    return Permission.sms.isGranted;
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Read SMS in [from]..[to] range, pre-filter for financial candidates.
  /// NOTE: Permission must have been granted during onboarding. This method
  /// will not request permission — it only checks if it's already granted.
  static Future<List<SmsCandidate>> readCandidates({
    required DateTime from,
    required DateTime to,
  }) async {
    final granted = await hasPermission();
    if (!granted) return [];

    final messages = await _query.querySms(kinds: [SmsQueryKind.inbox]);
    final candidates = <SmsCandidate>[];

    for (final sms in messages) {
      final body = sms.body ?? '';
      if (body.length < 10) continue;

      // Date filter using SMS timestamp
      final smsDate = sms.date;
      if (smsDate != null) {
        if (smsDate.isBefore(from) || smsDate.isAfter(to)) continue;
      }

      // Broad financial pre-filter
      if (!_isFinancialCandidate(body)) continue;

      candidates.add(SmsCandidate(
        smsId:   sms.id,
        body:    body,
        smsDate: smsDate,
      ));
    }

    return candidates;
  }
}
