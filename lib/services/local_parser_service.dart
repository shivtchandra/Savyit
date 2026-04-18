import '../models/transaction.dart';
import '../models/sms_candidate.dart';

/// BUNDLE for Isolate communication
class LocalParseResult {
  final List<Transaction> transactions;
  final int checked;
  final int regexMatched;
  final int modelFlagged;
  final int skipped;

  LocalParseResult({
    required this.transactions,
    required this.checked,
    required this.regexMatched,
    required this.modelFlagged,
    required this.skipped,
  });
}

/// Local SMS parser for Indian bank transactions
/// Works completely offline without any API
class LocalParserService {
  // We will now pass stats back in LocalParseResult instead of static vars 
  // because compute() runs in a separate isolate.

  // ─── CATEGORY DETECTION ────────────────────────────────────────────────────
  static String _categorize(String merchant, String body) {
    final text = '$merchant $body'.toLowerCase();

    // Food & Dining
    if (RegExp(r'(zomato|swiggy|uber\s*eats|food|restaurant|cafe|coffee|bakery|blinkit|zepto|bigbasket|grocery|market|supermarket|dining|starbucks|mcdonald|kfc|pizza|domino|burger|biryani|kitchen|dhaba|hotel|chaayos|dunkin|baskin|ice\s*cream|snack|meal|lunch|dinner|breakfast|canteen|tiffin|thali|haldiram|bikanervala)').hasMatch(text)) {
      return 'Food & Dining';
    }
    // Transport
    if (RegExp(r'(uber|ola|rapido|metro|irctc|railway|train|bus|redbus|flight|airline|indigo|spicejet|vistara|air\s*india|makemytrip|goibibo|cleartrip|yatra|petrol|diesel|fuel|hp\s|iocl|bpcl|shell|parking|toll|fastag|cab|taxi|auto|rickshaw|bike|rental)').hasMatch(text)) {
      return 'Transport';
    }
    // Shopping
    if (RegExp(r'(amazon|flipkart|myntra|ajio|meesho|nykaa|tata\s*cliq|snapdeal|shoppers\s*stop|lifestyle|westside|pantaloons|reliance|dmart|big\s*bazaar|mall|store|mart|retail|fashion|clothing|apparel|shoe|footwear|electronics|croma|vijay\s*sales|mobile|phone|laptop|gadget|decathlon|sports|furniture|ikea|home\s*centre)').hasMatch(text)) {
      return 'Shopping';
    }
    // Health
    if (RegExp(r'(hospital|clinic|doctor|medical|pharmacy|medicine|apollo|fortis|max|medanta|aiims|pharma|chemist|netmeds|pharmeasy|1mg|healthkart|diagnostic|lab|pathology|scan|xray|mri|dental|eye|optical|gym|fitness|yoga|cult|healthify)').hasMatch(text)) {
      return 'Health';
    }
    // Entertainment
    if (RegExp(r'(netflix|amazon\s*prime|hotstar|disney|spotify|gaana|youtube|jio\s*cinema|zee5|sonyliv|movie|cinema|pvr|inox|bookmyshow|ticket|concert|event|game|gaming|playstation|xbox|steam|pubg|subscription)').hasMatch(text)) {
      return 'Entertainment';
    }
    // Utilities & Bills
    if (RegExp(r'(electricity|electric|power|water|gas|lpg|indane|bharatgas|hp\s*gas|broadband|internet|wifi|jio|airtel|vodafone|vi\s|bsnl|mobile\s*recharge|dth|tata\s*sky|dish\s*tv|insurance|lic|premium|emi|loan|rent|maintenance|society|municipal|tax|postpaid|prepaid|bescom|tneb|kseb)').hasMatch(text)) {
      return 'Utilities & Bills';
    }
    // Transfer & Finance
    if (RegExp(r'(transfer|neft|imps|rtgs|upi|sent\s+to|received\s+from|self\s*transfer|fund\s*transfer|bank\s*transfer|investment|mutual\s*fund|sip|stock|share|zerodha|groww|upstox|paytm\s*money|fd|fixed\s*deposit|rd|ppf|nps|withdrawal|cash|atm|deposit)').hasMatch(text)) {
      return 'Transfer & Finance';
    }
    return 'Other';
  }

  static String _stripEmbeddingControls(String s) {
    return s
        .replaceAll('\u200E', '')
        .replaceAll('\u200F', '')
        .replaceAll('\u200B', '');
  }

  // ─── MERCHANT NAME CLEANING ────────────────────────────────────────────────
  static String _cleanMerchant(String? merchant) {
    if (merchant == null || merchant.isEmpty) return 'Unknown';

    String cleaned = _stripEmbeddingControls(merchant.trim());

    // Prefer human payee name when both name and UPI appear (e.g. "ZOMATO zomato@paytm")
    final upiInText =
        RegExp(r'([a-zA-Z0-9._-]+@[a-zA-Z0-9]{2,32})').firstMatch(cleaned);
    if (upiInText != null) {
      final before = cleaned.substring(0, upiInText.start).trim();
      if (before.length >= 3) {
        cleaned = before;
      } else {
        return _cleanUpiId(upiInText.group(1));
      }
    }

    cleaned = cleaned
        .replaceAll(
            RegExp(r'\b(vpa|val|info|ref|upi|trf)\b[:\s]+',
                caseSensitive: false),
            ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    cleaned = cleaned.replaceFirst(
      RegExp(
          r'\s+(ref\.?|bal\.?|avl\.?|custid|if\s+not|not\s+you)\b.*$',
          caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'^[*xX]+\d+\s*'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[*]{2,}\d{4}.*$'), '').trim();

    // Remove common noise words
    cleaned = cleaned.replaceAll(
        RegExp(r'\s*(pvt|ltd|limited|private|india|inr|rs)\s*',
            caseSensitive: false),
        ' ');
    cleaned = cleaned.trim();

    cleaned = cleaned.replaceFirst(
        RegExp(r'^(?:Mr|Mrs|Ms|Dr)\.?\s+', caseSensitive: false), '');

    if (cleaned.isEmpty || cleaned.length < 2) return 'Unknown';
    if (cleaned.length > 40) cleaned = cleaned.substring(0, 40);
    
    // Title case
    return cleaned.split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.length <= 2) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ').trim();
  }

  /// Parses common date stamps embedded in bank SMS (dd-MM-yy + time, or ddMonyy).
  static DateTime? _parseSmsBodyDate(String body) {
    final d1 = RegExp(
      r'(\d{2})-(\d{2})-(\d{2})\s*,\s*(\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(body);
    if (d1 != null) {
      final yy = int.tryParse(d1.group(3)!) ?? 0;
      final year = yy >= 70 ? 1900 + yy : 2000 + yy;
      final day = int.tryParse(d1.group(1)!) ?? 1;
      final month = int.tryParse(d1.group(2)!) ?? 1;
      final h = int.tryParse(d1.group(4)!) ?? 0;
      final min = int.tryParse(d1.group(5)!) ?? 0;
      final s = int.tryParse(d1.group(6)!) ?? 0;
      try {
        return DateTime(year, month, day, h, min, s);
      } catch (_) {}
    }
    const mon = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final d2 = RegExp(
      r'(\d{2})(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)(\d{2})',
      caseSensitive: false,
    ).firstMatch(body);
    if (d2 != null) {
      final day = int.tryParse(d2.group(1)!) ?? 1;
      final mStr = d2.group(2)!.toLowerCase();
      final month = mon[mStr.substring(0, 3)] ?? 1;
      final yy = int.tryParse(d2.group(3)!) ?? 0;
      final year = yy >= 70 ? 1900 + yy : 2000 + yy;
      try {
        return DateTime(year, month, day);
      } catch (_) {}
    }
    return null;
  }

  // ─── MAIN PARSER ───────────────────────────────────────────────────────────
  static Transaction? parseSms(SmsCandidate candidate, {Map<String, int>? stats}) {
    stats?['total'] = (stats['total'] ?? 0) + 1;
    final body = candidate.body;
    if (body.isEmpty) return null;

    final bodyLower = body.toLowerCase();
    
    if (_isOtpOrPromo(bodyLower)) {
      stats?['skipped'] = (stats['skipped'] ?? 0) + 1;
      return null;
    }

    final idForTxn = candidate.smsId != null
        ? 'sms_local_${candidate.smsId}'
        : 'sms_local_${DateTime.now().microsecondsSinceEpoch}';

    RegExpMatch? match;
    String? amountStr;
    String? merchantStr;
    String type = 'debit';
    DateTime date = _parseSmsBodyDate(body) ?? candidate.smsDate ?? DateTime.now();

    // Pattern Matching Logic
    final pAxisUpiP2m = RegExp(
      r'(?:INR|Rs\.?|₹)\s+([\d,]+\.?\d*)\s+debited[\s\S]{0,1000}?UPI/P2[M|P]/\d+/(.+?)(?=\s*Not you|\nRead more|\s*$)',
      caseSensitive: false,
    );
    final pSbiDebitedTrf = RegExp(
      r'A/?C\s+\S*?([xX*]*\d+)\s+debited\s+by\s+([\d,]+\.?\d*)\s+on\s+date\s+\d{2}[A-Za-z-]{3,}\d{2}.{0,50}?trf\s+to\s+(?:Mr|Ms|Mrs|Dr)?\s*(.+?)\s+(?:Refno|Ref\.?|Ref\s+No|at)',
      caseSensitive: false,
    );
    final p1 = RegExp(
      r'debited\s+(?:by\s+)?(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)\s+(?:for\s+)?(?:vpa\s+)?([a-zA-Z0-9._-]+@[a-zA-Z0-9]+)',
      caseSensitive: false,
    );
    final p2 = RegExp(
      r'(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)\s+(?:has\s+been\s+)?debited\s+(?:from\s+)?[\s\S]*?\b(?:to|at|info|towards)\b\s*[:\s]?\s*(.+?)(?:\s+on\s+|\s+ref\s*[:\s]|\s+avl\s*$|\.\s*avl|\s+available|\s+if\s+|\s+custid|\s+not\s+you|\s*$)',
      caseSensitive: false,
    );
    final p3 = RegExp(
      r'(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)\s+(?:has\s+been\s+)?credited\s+(?:to\s+)?.*?(?:from|by)\s*(.*?)(?:\s+on|\s+ref|\s+avl|\s*$)',
      caseSensitive: false,
    );
    final p11 = RegExp(
      r'(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*).*?(debited|credited|paid|received|spent|txn|charge)',
      caseSensitive: false,
    );
    // Single-line INR/Rs debited (HDFC, ICICI, many PSUs)
    final pInrDebited = RegExp(
      r'(?:inr|rs\.?|₹)\s*([\d,]+\.?\d*)\s+debited\b',
      caseSensitive: false,
    );
    final pInrCredited = RegExp(
      r'(?:inr|rs\.?|₹)\s*([\d,]+\.?\d*)\s+credited\b',
      caseSensitive: false,
    );
    // Paytm / wallet: "Paid Rs. 99 to MERCHANT"
    final pPaidTo = RegExp(
      r'\bpaid\s+(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)\s+(?:to|for)\s+(.+?)(?:\s+on\s+|\s+using|\s+via\s+|\s+upi|\s*\||\s*$)',
      caseSensitive: false,
    );
    // ATM: "Cash withdrawal of Rs 2000.00 from A/c…"
    final pCashWithdrawal = RegExp(
      r'withdrawal\s+of\s+(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    );
    // Card: "Transaction of Rs 1299.00 on your … Card … at FLIPKART on …"
    final pCardTxnOfRsAt = RegExp(
      r'transaction\s+of\s+(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)[\s\S]{0,200}?\bat\s+([A-Za-z0-9][A-Za-z0-9\s&]{1,40}?)(?:\s+on\s|\s*$)',
      caseSensitive: false,
    );
    // Card: "Rs 599.00 transaction at AMAZON on …"
    final pRsTxnAt = RegExp(
      r'(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)\s+transaction\s+at\s+([A-Za-z0-9][A-Za-z0-9\s&]{1,40}?)(?:\s+on\s|\s*$)',
      caseSensitive: false,
    );

    if ((match = pAxisUpiP2m.firstMatch(body)) != null) {
      amountStr = match!.group(1);
      merchantStr = _stripEmbeddingControls(match!.group(2)?.trim() ?? '');
      type = 'debit';
    } else if ((match = pSbiDebitedTrf.firstMatch(body)) != null) {
      amountStr = match!.group(2);
      merchantStr = match!.group(3);
      type = 'debit';
    } else if ((match = p1.firstMatch(body)) != null) {
      amountStr = match!.group(1);
      merchantStr = _cleanUpiId(match!.group(2));
      type = 'debit';
    } else if ((match = p2.firstMatch(body)) != null) {
      amountStr = match!.group(1);
      merchantStr = match!.group(2);
      type = 'debit';
    } else if ((match = p3.firstMatch(body)) != null) {
      amountStr = match!.group(1);
      merchantStr = match!.group(2);
      type = 'credit';
    } else if ((match = pInrDebited.firstMatch(body)) != null) {
      amountStr = match!.group(1);
      merchantStr = _extractMerchantFallback(body);
      type = 'debit';
    } else if ((match = pInrCredited.firstMatch(body)) != null) {
      amountStr = match!.group(1);
      merchantStr = _extractMerchantFallback(body);
      type = 'credit';
    } else if ((match = pPaidTo.firstMatch(body)) != null) {
      amountStr = match!.group(1);
      merchantStr = match!.group(2);
      type = 'debit';
    } else if ((match = pCashWithdrawal.firstMatch(body)) != null) {
      amountStr = match!.group(1);
      merchantStr = 'ATM withdrawal';
      type = 'debit';
    } else if ((match = pCardTxnOfRsAt.firstMatch(body)) != null) {
      amountStr = match!.group(1);
      merchantStr = match!.group(2);
      type = 'debit';
    } else if ((match = pRsTxnAt.firstMatch(body)) != null) {
      amountStr = match!.group(1);
      merchantStr = match!.group(2);
      type = 'debit';
    } else if ((match = p11.firstMatch(body)) != null) {
      amountStr = match!.group(1);
      final action = match!.group(2)!.toLowerCase();
      type = (action == 'credited' || action == 'received') ? 'credit' : 'debit';
      merchantStr = _extractMerchantFallback(body);
    }

    if (amountStr != null) {
      stats?['regex'] = (stats['regex'] ?? 0) + 1;
      final amount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
      if (amount > 0) {
        final merchant = _cleanMerchant(merchantStr);
        return Transaction(
          id: idForTxn,
          merchant: merchant,
          category: _categorize(merchant, body),
          bank: _inferBank(body),
          account: _inferAccount(body),
          amount: amount,
          date: date,
          type: type,
          raw: body,
          categoryNeedsReview: false,
        );
      }
    }

    return _fallbackExtract(
      body: body,
      bodyLower: bodyLower,
      idForTxn: idForTxn,
      date: date,
      stats: stats,
    );
  }

  static bool _isOtpOrPromo(String body) {
    if (RegExp(r'(otp|one\s*time\s*password|verification\s*code|pin\s*is|cvv|do\s*not\s*share|expires\s*in)').hasMatch(body)) return true;
    if (RegExp(r'(flat\s+\d+%\s+off|use\s+code|shop\s+now|sale|offer|coupon|discount)').hasMatch(body)) {
      if (!body.contains('debited') && !body.contains('credited') && !body.contains('paid')) return true;
    }
    return false;
  }

  static String _cleanUpiId(String? upiId) {
    if (upiId == null || upiId.isEmpty) return 'Unknown';
    final parts = upiId.split('@');
    if (parts.isEmpty) return upiId;
    String name = parts[0].replaceAll(RegExp(r'^\d+'), '').replaceAll('.', ' ').replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (name.isEmpty) return upiId;
    return name.split(' ').map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ').trim();
  }

  static String? _extractMerchantFallback(String body) {
    final info = RegExp(r"info[:\s]+([A-Za-z0-9\s&'.-]+?)(?:\s+on\s+|\s+ref|\s*$)", caseSensitive: false).firstMatch(body);
    if (info != null) return info.group(1);
    final towards = RegExp(r"\btowards\s+([A-Za-z0-9\s&'.-]+?)(?:\s+ref|\s+on\s+|\s*$)", caseSensitive: false).firstMatch(body);
    if (towards != null) return towards.group(1);
    final to = RegExp(r"(?:\bto\b|\bat\b)\s+([A-Za-z0-9\s&'.-]+?)(?:\s+on\s+|\s+ref|\s*$)", caseSensitive: false).firstMatch(body);
    if (to != null) return to.group(1);
    // "VPA zomato@paytm ZOMATO Ref …" — payee name after UPI id
    final vpaTail = RegExp(
      r'vpa\s+[a-z0-9._-]+@[a-z0-9.]+\s+([A-Za-z0-9][A-Za-z0-9\s&]{1,48}?)(?:\s+ref|\s+Ref|\s+on\s|\s*$)',
      caseSensitive: false,
    ).firstMatch(body);
    if (vpaTail != null) return vpaTail.group(1);
    final upiOnly =
        RegExp(r'\b([a-z0-9][a-z0-9._-]{1,24}@[a-z0-9._-]+)\b', caseSensitive: false)
            .firstMatch(body);
    if (upiOnly != null) return _cleanUpiId(upiOnly.group(1));
    return null;
  }

  static String _inferBank(String body) {
    final text = body.toLowerCase();
    if (text.contains('hdfc')) return 'HDFC';
    if (text.contains('icici')) return 'ICICI';
    if (text.contains('sbi')) return 'SBI';
    if (text.contains('axis')) return 'Axis';
    if (text.contains('kotak')) return 'Kotak';
    return 'Bank';
  }

  static String? _inferAccount(String body) {
    final match = RegExp(r'a/?c\s*(?:no\.?)?\s*[*xX]+(\d{4})', caseSensitive: false).firstMatch(body);
    return match?.group(1);
  }

  /// True when the SMS body looks like a bank/UPI line item (prefilter already passed;
  /// this avoids grabbing "available balance" amounts at the end of unrelated texts).
  static bool _bodyHasFinancialSignals(String bodyLower) {
    final hasAmt =
        RegExp(r'(?:rs\.?|inr|₹)\s*[\d,]+').hasMatch(bodyLower);
    final hasVerb = RegExp(
      r'\b(debited|credited|paid|spent|sent|purchase|imps|neft|rtgs|upi|txn|transaction|transfer|trf|withdrawal)\b',
      caseSensitive: false,
    ).hasMatch(bodyLower);
    return hasAmt && hasVerb;
  }

  /// Prefer the transaction amount near debited/credited/paid — not "Avl Bal" at the end.
  static Transaction? _fallbackExtract({
    required String body,
    required String bodyLower,
    required String idForTxn,
    required DateTime date,
    Map<String, int>? stats,
  }) {
    if (!_bodyHasFinancialSignals(bodyLower)) return null;

    final patterns = <RegExp>[
      RegExp(
        r'\bdebited\s+by\s+(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(
        r'\bcredited\s+by\s+(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:inr|rs\.?|₹)\s*([\d,]+\.?\d*)\s+debited\b',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:inr|rs\.?|₹)\s*([\d,]+\.?\d*)\s+credited\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\bdebited\b[\s\S]{0,120}?(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(
        r'\bcredited\b[\s\S]{0,120}?(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)[\s\S]{0,72}?\bdebited\b',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)[\s\S]{0,72}?\bcredited\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\bpaid\s+(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(
        r'\bsent\s+(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(
        r'\bspent\s+(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)',
        caseSensitive: false,
      ),
    ];

    for (final re in patterns) {
      final m = re.firstMatch(body);
      if (m == null) continue;
      final rawAmt = m.group(1);
      if (rawAmt == null) continue;
      final amount = double.tryParse(rawAmt.replaceAll(',', '')) ?? 0.0;
      if (amount <= 0) continue;

      final isCredit = bodyLower.contains('credited') &&
          !bodyLower.contains('debited');
      final type = isCredit ? 'credit' : 'debit';

      stats?['model'] = (stats['model'] ?? 0) + 1;
      final merchant = _cleanMerchant(_extractMerchantFallback(body));
      return Transaction(
        id: idForTxn,
        merchant: merchant,
        category: _categorize(merchant, body),
        bank: _inferBank(body),
        account: _inferAccount(body),
        amount: amount,
        date: date,
        type: type,
        raw: body,
        categoryNeedsReview: merchant == 'Unknown' || merchant.length < 2,
      );
    }

    return null;
  }

  static LocalParseResult parseCandidates(List<SmsCandidate> candidates) {
    final transactions = <Transaction>[];
    final stats = <String, int>{
      'total': 0,
      'regex': 0,
      'model': 0,
      'skipped': 0,
    };

    for (final c in candidates) {
      final t = parseSms(c, stats: stats);
      if (t != null) transactions.add(t);
    }

    return LocalParseResult(
      transactions: transactions,
      checked: stats['total'] ?? 0,
      regexMatched: stats['regex'] ?? 0,
      modelFlagged: stats['model'] ?? 0,
      skipped: stats['skipped'] ?? 0,
    );
  }
}
