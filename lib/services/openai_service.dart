// lib/services/openai_service.dart
// PDF / SMS classification via OpenAI Chat Completions (proxied through Vercel + Firebase).

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/sms_candidate.dart';

class OpenAIService {
  static const _prefsKey = 'openai_api_key';

  /// Chat model (must be allowed on your OpenAI account; passed to the proxy).
  static const String chatModel = 'gpt-5.2-mini';

  /// Production OpenAI proxy (Vercel). Uses Firebase ID token — no app-bundled API key.
  static const String cloudProxyBaseUrl = 'https://savyit-2ntk.vercel.app';

  static Uri get _proxyChatUri =>
      Uri.parse('$cloudProxyBaseUrl/api/chat');

  /// True when a Firebase user is signed in (required for cloud AI).
  static bool get canUseCloudAi =>
      FirebaseAuth.instance.currentUser != null;

  /// User-provided key (legacy / optional). Cloud AI does not use this.
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_prefsKey)?.trim();
    if (key == null || key.isEmpty) return null;
    return key;
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final t = key.trim();
    if (t.isEmpty) {
      await prefs.remove(_prefsKey);
      return;
    }
    await prefs.setString(_prefsKey, t);
  }

  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static void _ensureProxyOk(http.Response res) {
    if (res.statusCode == 200) return;
    final snippet = res.body.length > 400
        ? '${res.body.substring(0, 400)}…'
        : res.body;
    throw Exception('AI proxy HTTP ${res.statusCode}: $snippet');
  }

  /// POST [messages] to Vercel proxy with Firebase ID token. Returns raw OpenAI-shaped JSON body.
  static Future<http.Response> _chatViaProxy({
    required List<Map<String, dynamic>> messages,
    double? temperature,
    int? maxTokens,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(
        'Sign in to use AI. Cloud features need a Firebase account.',
      );
    }
    final token = await user.getIdToken();
    final body = <String, dynamic>{
      'messages': messages,
      'model': chatModel,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
    };
    return http.post(
      _proxyChatUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  /// Best-effort connectivity check (signed-in users only).
  static Future<bool> validateKey(String key) async {
    try {
      final res = await _chatViaProxy(
        messages: const [
          {'role': 'user', 'content': 'Say OK'},
        ],
        maxTokens: 5,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Classify transactions from raw text (e.g. PDF extraction).
  static Future<List<Transaction>> classifyText({
    required String text,
    void Function(String status)? onStatus,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];

    onStatus?.call('Sending ${trimmed.length} chars to AI…');

    final systemPrompt =
        '''You are a financial PDF statement parser specializing in Indian payment apps (Google Pay, PhonePe, Paytm, etc.) and bank statements.

The user will provide raw text extracted from a PDF statement. Extract ALL payment/transaction entries.

GPay statements typically have lines like:
- "Feb 21, 2026 Paid to MERCHANT_NAME ₹AMOUNT"
- "Feb 20, 2026 Received from PERSON_NAME ₹AMOUNT"
- "Paid to Faizique Foods ₹46.00"
- "Received from John Doe ₹500.00"

Bank statements may have tabular data with columns for date, description, debit, credit, balance.

Respond ONLY with a valid JSON array. Each item MUST follow this schema:
{
  "is_transaction": true,
  "type": "credit" or "debit",
  "amount": 499.00,
  "merchant": "Clean Merchant Name",
  "category": "Food & Dining|Transport|Shopping|Health|Entertainment|Utilities & Bills|Transfer|Other",
  "bank": "GPay|PhonePe|Paytm|HDFC|SBI|etc",
  "date": "YYYY-MM-DD"
}

Rules:
- "Paid to" = debit. "Received from" = credit.
- Extract EVERY payment line, even small amounts.
- Return ONLY the JSON array, no other text or explanation.
- If year is shown as 2-digit (e.g. "26"), interpret as 2026.
- If you cannot find any transactions, return an empty array [].''';

    try {
      final res = await _chatViaProxy(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content':
                'Extract all transactions from this statement text:\n\n$trimmed',
          },
        ],
        temperature: 0.0,
        maxTokens: 4000,
      );

      _ensureProxyOk(res);

      onStatus?.call('Parsing AI response…');
      return _parseJsonResponse(res.body, null);
    } catch (e) {
      rethrow;
    }
  }

  static String _getSystemPrompt() {
    return '''You are a financial statement parser. 
Extract all real bank/UPI transactions from the provided text.

Respond with a JSON array. Each item MUST have:
- "is_transaction": true/false
- If true:
  - "type": "credit" or "debit"
  - "amount": number (e.g. 499.00)
  - "merchant": string (who was paid or who paid you, clean name)
  - "category": one of: "Food & Dining", "Transport", "Shopping", "Health", "Entertainment", "Utilities & Bills", "Transfer", "Other"
  - "bank": string (e.g. "GPay", "HDFC", "SBI")
  - "date": "YYYY-MM-DD"

Rules:
- OTPs, balance inquiries, and account alerts without a transaction are NOT transactions.
- Promotional messages, discount offers, cashback offers, sale announcements, and ads are NOT transactions. Set is_transaction to false.
- Messages from e-commerce brands (Snitch, Myntra, Amazon, Flipkart, etc.) that mention "offer", "off", "coupon", "use code", "shop now", "deal" are ads — NOT transactions.
- "Cashback earned" notifications from shopping apps are NOT real bank credits — set is_transaction to false.
- Only mark is_transaction true if an actual bank debit/credit occurred (e.g. "debited from your account", "credited to your account", "Rs X paid to").
- Always return a valid JSON array. No extra text.''';
  }

  static List<Transaction> _parseJsonResponse(
      String responseBody, DateTime? fallbackDate) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid response from AI API: $e');
    }

    final content =
        data['choices']?[0]?['message']?['content'] as String? ?? '';
    if (content.isEmpty) return [];

    String jsonStr = content.trim();
    if (jsonStr.contains('```')) {
      final match =
          RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(jsonStr);
      if (match != null) {
        jsonStr = match.group(1) ?? jsonStr;
      } else {
        jsonStr = jsonStr
            .replaceAll(RegExp(r'^```\w*\n?'), '')
            .replaceAll(RegExp(r'\n?```$'), '');
      }
    }
    jsonStr = jsonStr.trim();

    final startBracket = jsonStr.indexOf('[');
    final endBracket = jsonStr.lastIndexOf(']');
    if (startBracket != -1 && endBracket != -1 && endBracket > startBracket) {
      jsonStr = jsonStr.substring(startBracket, endBracket + 1);
    }

    List<dynamic> parsed;
    try {
      parsed = jsonDecode(jsonStr) as List<dynamic>;
    } catch (_) {
      final lastCommaBrace = jsonStr.lastIndexOf('},');
      if (lastCommaBrace > 0) {
        try {
          parsed = jsonDecode('${jsonStr.substring(0, lastCommaBrace + 1)}]')
              as List<dynamic>;
        } catch (e2) {
          final lastBrace = jsonStr.lastIndexOf('}');
          if (lastBrace > 0) {
            try {
              parsed = jsonDecode('${jsonStr.substring(0, lastBrace + 1)}]')
                  as List<dynamic>;
            } catch (e3) {
              throw FormatException('Could not recover truncated JSON: $e3');
            }
          } else {
            throw FormatException(
                'Invalid JSON structure and no recovery possible.',
            );
          }
        }
      } else {
        throw FormatException('Truncated or invalid JSON array');
      }
    }

    final txns = <Transaction>[];
    for (final item in parsed) {
      if (item is! Map) continue;
      if (item['is_transaction'] != true) continue;

      final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0) continue;

      DateTime date;
      if (item['date'] != null) {
        try {
          date = DateTime.parse(item['date'] as String);
        } catch (_) {
          date = fallbackDate ?? DateTime.now();
        }
      } else {
        date = fallbackDate ?? DateTime.now();
      }

      final cat = item['category']?.toString() ?? 'Other';
      txns.add(Transaction(
        id: 'pdf_${DateTime.now().microsecondsSinceEpoch}_${txns.length}_${amount.toStringAsFixed(0)}',
        merchant: item['merchant'] ?? 'Unknown',
        category: cat,
        bank: item['bank'] ?? 'Unknown',
        account: null,
        amount: amount,
        date: date,
        type: item['type'] ?? 'debit',
        raw: '',
        categoryNeedsReview: cat == 'Other',
      ));
    }
    return txns;
  }

  static Future<List<Transaction>> classify({
    required List<SmsCandidate> candidates,
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = <Transaction>[];
    const batchSize = 15;
    final batches = <List<SmsCandidate>>[];

    for (var i = 0; i < candidates.length; i += batchSize) {
      batches.add(candidates.sublist(
          i,
          i + batchSize > candidates.length
              ? candidates.length
              : i + batchSize));
    }

    int completed = 0;
    for (final batch in batches) {
      final batchResults = await _classifySmsBatch(batch);
      results.addAll(batchResults);
      completed += batch.length;
      onProgress?.call(completed, candidates.length);
    }

    return results;
  }

  static Future<List<Transaction>> _classifySmsBatch(
    List<SmsCandidate> batch,
  ) async {
    final numberedMessages = batch
        .asMap()
        .entries
        .map((e) => '[${e.key + 1}] ${e.value.body}')
        .join('\n\n');

    final systemPrompt =
        '${_getSystemPrompt()}\nRespond with an array where each object also includes "index": number.';

    try {
      final res = await _chatViaProxy(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': numberedMessages},
        ],
        temperature: 0.1,
        maxTokens: 4096,
      );

      _ensureProxyOk(res);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final content =
          data['choices']?[0]?['message']?['content'] as String? ?? '';
      if (content.isEmpty) return [];

      String jsonStr = content.trim();
      if (jsonStr.contains('```')) {
        final fence =
            RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(jsonStr);
        if (fence != null) {
          jsonStr = fence.group(1) ?? jsonStr;
        } else {
          jsonStr = jsonStr
              .replaceAll(RegExp(r'^```\w*\n?'), '')
              .replaceAll(RegExp(r'\n?```$'), '');
        }
      }
      jsonStr = jsonStr.trim();
      final startBracket = jsonStr.indexOf('[');
      final endBracket = jsonStr.lastIndexOf(']');
      if (startBracket != -1 && endBracket != -1 && endBracket > startBracket) {
        jsonStr = jsonStr.substring(startBracket, endBracket + 1);
      }

      final parsed = jsonDecode(jsonStr) as List<dynamic>;
      final txns = <Transaction>[];

      for (final item in parsed) {
        if (item is! Map) continue;
        if (item['is_transaction'] != true) continue;

        final rawIdx = item['index'];
        final idx1 = rawIdx is int
            ? rawIdx
            : (rawIdx is num ? rawIdx.toInt() : int.tryParse('$rawIdx') ?? 0);
        final idx = idx1 - 1;
        if (idx < 0 || idx >= batch.length) continue;
        final candidate = batch[idx];

        final amount = (item['amount'] as num?)?.toDouble();
        if (amount == null || amount <= 0) continue;

        DateTime date;
        if (item['date'] != null) {
          try {
            date = DateTime.parse(item['date'] as String);
          } catch (_) {
            date = candidate.smsDate ?? DateTime.now();
          }
        } else {
          date = candidate.smsDate ?? DateTime.now();
        }

        final cat = item['category']?.toString() ?? 'Other';
        txns.add(Transaction(
          id: candidate.smsId != null
              ? 'sms_${candidate.smsId}'
              : 'sms_${DateTime.now().microsecondsSinceEpoch}_${idx}_${amount.toStringAsFixed(0)}',
          merchant: item['merchant'] ?? 'Unknown',
          category: cat,
          bank: item['bank'] ?? 'Bank',
          account: null,
          amount: amount,
          date: date,
          type: item['type'] ?? 'debit',
          raw: candidate.body,
          categoryNeedsReview: cat == 'Other',
        ));
      }
      return txns;
    } catch (e) {
      throw Exception('SMS batch parse failed: $e');
    }
  }

  static Future<Map<String, dynamic>> generateFinancialInsight({
    required Map<String, dynamic> userProfile,
    required double totalIncome,
    required double totalExpenses,
    required double currentBalance,
    required double savingsRate,
    required Map<String, double> categoryBreakdown,
    required String period,
    Map<String, dynamic>? financialPlan,
  }) async {
    final categories = categoryBreakdown.entries
        .map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}')
        .join(', ');
    final MapEntry<String, double>? topCategory =
        categoryBreakdown.entries.isEmpty
            ? null
            : (categoryBreakdown.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .first;

    final goals = (userProfile['goals'] as List?)?.join(', ') ?? 'Not set';
    final planGoals = (financialPlan?['goals'] as List?)?.join(', ') ?? goals;
    final planSavingsRate = (financialPlan?['savingsRate'] as num?)?.toDouble();
    final planMonthlySavings =
        (financialPlan?['monthlySavings'] as num?)?.toDouble();
    final planMonthlyInvestment =
        (financialPlan?['monthlyInvestment'] as num?)?.toDouble();
    final planGeneratedAt = financialPlan?['generatedAt']?.toString();

    final prompt =
        '''You are a friendly, warm financial advisor chatbot named Savyit AI.

The user has shared their profile, recent spending, and current financial plan. Give them a personalized financial health check.

USER PROFILE:
- Name: ${userProfile['name']}
- Age: ${userProfile['ageRange'] ?? 'Not provided'}
- Occupation: ${userProfile['occupation'] ?? 'Not provided'}
- Monthly Income Range: ${userProfile['monthlyIncome'] ?? 'Not provided'}
- Financial Goals: $goals

SPENDING DATA ($period):
- Total Income: ₹${totalIncome.toStringAsFixed(0)}
- Total Expenses: ₹${totalExpenses.toStringAsFixed(0)}
- Current Balance: ₹${currentBalance.toStringAsFixed(0)}
- Savings Rate: ${savingsRate.toStringAsFixed(1)}%
- Category Breakdown: $categories
- Highest Spend Category: ${topCategory?.key ?? 'Not available'} ${topCategory != null ? '(₹${topCategory.value.toStringAsFixed(0)})' : ''}

FINANCIAL PLAN (if available):
- Plan Goals: $planGoals
- Planned Savings Rate: ${planSavingsRate?.toStringAsFixed(1) ?? 'Not available'}%
- Planned Monthly Savings: ₹${planMonthlySavings?.toStringAsFixed(0) ?? 'Not available'}
- Planned Monthly Investment (SIP): ₹${planMonthlyInvestment?.toStringAsFixed(0) ?? 'Not available'}
- Plan Generated At: ${planGeneratedAt ?? 'Not available'}

Respond ONLY with valid JSON (no markdown, no code fences) in this exact format:
{
  "verdict": "On Track" or "Needs Attention" or "Off Track",
  "status_icon": "success" or "warning" or "error",
  "mood": "happy" or "neutral" or "concerned",
  "mood_line": "One short line that sounds like a money buddy emotion update based on spending vs income.",
  "summary": "A 3-4 sentence personalized assessment. Be encouraging but honest. Mention user name, goals, current balance, and one concrete spending pattern with numbers.",
  "wins": ["2 concise positive observations"],
  "watchouts": ["2 concise risk flags"],
  "tips": ["3 specific, actionable tips"],
  "next_step": "One clear next action for this week, with amount/category if possible."
}

Be warm and use their name. If they are young (18-27), be encouraging. If older, be practical.
You MUST explicitly assess how they are progressing toward their dreams/goals based on current balance and whether they are aligned with their financial plan.''';

    try {
      final res = await _chatViaProxy(
        messages: [
          {'role': 'user', 'content': prompt},
        ],
        maxTokens: 500,
        temperature: 0.7,
      );

      if (res.statusCode != 200) {
        throw Exception('API error: ${res.statusCode}');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final content = body['choices']?[0]?['message']?['content'] as String?;

      if (content == null || content.isEmpty) {
        throw Exception('Empty AI response');
      }

      String cleaned = content.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```json?\n?'), '')
            .replaceFirst(RegExp(r'\n?```$'), '');
      }

      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      List<String> asStringList(dynamic value) {
        if (value is! List) return const [];
        return value
            .whereType<dynamic>()
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      final netFlow = totalIncome - totalExpenses;
      final fallbackMood = netFlow < 0 || savingsRate < 0
          ? 'concerned'
          : savingsRate >= 20
              ? 'happy'
              : 'neutral';

      return {
        'verdict': parsed['verdict'] ?? 'Unknown',
        'status_icon': parsed['status_icon'] ?? 'success',
        'mood': (parsed['mood'] ?? fallbackMood).toString(),
        'mood_line': (parsed['mood_line'] ?? '').toString(),
        'summary': parsed['summary'] ?? 'Could not generate insight.',
        'wins': asStringList(parsed['wins']),
        'watchouts': asStringList(parsed['watchouts']),
        'tips': asStringList(parsed['tips']),
        'next_step': (parsed['next_step'] ?? '').toString(),
      };
    } catch (e) {
      return {
        'verdict': 'Error',
        'status_icon': 'error',
        'mood': 'neutral',
        'mood_line': '',
        'summary':
            'Could not generate insights right now. Please try again later.',
        'wins': <String>[],
        'watchouts': <String>[],
        'tips': <String>[],
        'next_step': '',
      };
    }
  }
}
