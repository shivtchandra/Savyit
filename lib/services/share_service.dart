// lib/services/share_service.dart
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';

/// Rotating, neo-brutalist energy for share sheets — same personality as the app UI.
class SavyitShareCopy {
  SavyitShareCopy._();

  static int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h.abs();
  }

  static String _pick(String salt, List<String> lines) =>
      lines[_hash(salt) % lines.length];

  static String _banner() {
    return '''
▛▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▜
▌  S A V Y I T  ·  M O N E Y  ▐
▙▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▟''';
  }

  static String _footer(String salt) => _pick(salt, [
        '⚡ Tracked in Savyit — bank SMS → pretty charts. Your spreadsheet is crying.',
        '🤑 Made with Savyit. Neo-brutal finance. Download & flex responsibly.',
        '✨ Savyit: where rupees get a glow-up. Tell a friend who still uses Notes.',
        '📣 This graph slaps. The app is called Savyit — you\'re welcome.',
        '🔥 Money diary, but make it design-magazine. Savyit on iOS/Android.',
      ]);

  // ── Home / visual report (PNG + caption) ─────────────────────
  static String visualReportSubject(String period) =>
      _pick(period, [
        'Savyit money snapshot — $period',
        'My rupee weather report ($period) ★ Savyit',
        'Proof I track spending ($period) — Savyit dump',
        'Financial chaos, beautifully framed · $period',
        'Not boring money stats ($period) ✦ Savyit',
      ]);

  static String visualReportCaption({
    required String period,
    required String inflow,
    required String outflow,
    required String net,
  }) {
    final hook = _pick('$period|$net', [
          'Catch these numbers before they run away:',
          'Behold: my cashflow in high-res neo glory.',
          'Sharing because my money story deserves an audience.',
          'Screenshot energy, but make it official:',
          'Peer pressure to download Savyit starts now:',
        ]);
    return '$hook\n\n${_banner()}\n'
        'Period → $period\n'
        '━━━━━━━━━━━━━━━━━━━━\n'
        'Inflow   $inflow\n'
        'Outflow  $outflow\n'
        'Net      $net\n'
        '━━━━━━━━━━━━━━━━━━━━\n'
        '${_footer(period)}';
  }

  static String heroShareTitle(String periodSalt) => _pick(periodSalt, [
        'Blast this report',
        'Share the money flex',
        'Ship my Savyit snapshot',
        'Export the neo receipt',
        'Leak the high-res stats',
      ]);

  static String heroShareSubtitle(String periodSalt) => _pick('sub|$periodSalt', [
        'One tap · chunky card · make them jealous',
        'PNG so crisp it has a shadow IRL',
        'Your group chat isn\'t ready',
        'Spreadsheet users look away',
        'Attract humans to better money habits',
      ]);

  static String loadingBlurb() => _pick(
        DateTime.now().millisecondsSinceEpoch.toString(),
        [
          'Baking pixels…',
          'Sharpening the lime shadow…',
          'Teaching rupees to pose…',
          'Almost illegal levels of crisp…',
          'Hold up — neo-brutalism incoming…',
        ],
      );

  // ── Group split ──────────────────────────────────────────────
  static String settlementSubject() => _pick('split', [
        'Savyit says who owes who (settlement card)',
        'Group split receipt — Savyit',
        'We did the math so the group chat doesn\'t have to',
      ]);

  static String settlementBody() => _pick('splitbody', [
        'Settlement card attached — split fairly, look unfairly good. Made in Savyit.',
        'Here\'s who pays whom. Tracked in Savyit. Argue with the screenshot, not me.',
        'Neo-brutalist IOU energy. Open Savyit if you want this life.',
      ]);

  static String settlementButtonTitle() => _pick('stbtn', [
        'Share settlement card',
        'Ship the IOU receipt',
        'Leak who pays whom',
        'Export group split receipt',
      ]);

  static String settlementButtonSubtitle() => _pick('stsub', [
        'PNG · chunky shadows · no drama (okay, less drama)',
        'Your group chat isn\'t ready for this clarity',
        'Fair math, unfairly good-looking',
      ]);

  // ── Plain-text summaries ─────────────────────────────────────
  static String monthlySummaryHeader(String period) {
    final vibe = _pick(period, [
          'Savyit expense dump',
          'Money mood board',
          'Rupee receipt (text edition)',
        ]);
    return '$vibe\n${_banner()}\nPeriod: $period\n━━━━━━━━━━━━━━━━━━━━';
  }

  static String sectorHeader(String category) {
    return '${_banner()}\nSector spotlight: $category\n━━━━━━━━━━━━━━━━━━━━';
  }

  static String exportPdfSubject() => _pick('pdfsub', [
        'Savyit PDF — my transactions (flex edition)',
        'Rupee paper trail · exported from Savyit',
        'Transaction receipt pack (Savyit export)',
      ]);

  static String exportPdfCaption() => _pick('pdfcap', [
        'Attached: my Savyit PDF. Yes, it\'s allowed to look this organized.',
        'PDF fresh from Savyit — bank SMS energy, design-magazine layout.',
        'Export proof for future you (and your accountant\'s raised eyebrow).',
      ]);

  static String exportCsvSubject() => _pick('csvsub', [
        'Savyit CSV — spreadsheet hive mind',
        'Raw transaction rows from Savyit',
      ]);

  static String exportCsvCaption() => _pick('csvcap', [
        'CSV from Savyit — plug into Sheets and pretend you planned this all along.',
        'Spreadsheet mode: unlocked. Savyit did the boring part.',
      ]);
}

class ShareService {
  static NumberFormat _currencyFmt(String symbol) =>
      NumberFormat.currency(locale: 'en_IN', symbol: symbol, decimalDigits: 0);

  /// Shares a summary of the current period.
  static Future<void> shareMonthlySummary({
    required String period,
    required double inflow,
    required double outflow,
    required int count,
    required Map<String, double> sectorBreakdown,
    String currencySymbol = '₹',
  }) async {
    final cf = _currencyFmt(currencySymbol);
    final buffer = StringBuffer();
    buffer.writeln(SavyitShareCopy.monthlySummaryHeader(period));
    buffer.writeln('Total Inflow: ${cf.format(inflow)}');
    buffer.writeln('Total Outflow: ${cf.format(outflow)}');
    buffer.writeln('Transactions: $count');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('\nSpending by sector (loudest first):');

    final sortedSectors = sectorBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedSectors) {
      if (entry.value > 0) {
        final percentage = (entry.value / outflow * 100).toStringAsFixed(1);
        buffer.writeln(
            '▸ ${entry.key}: ${cf.format(entry.value)} ($percentage%)');
      }
    }

    buffer.writeln('\n${SavyitShareCopy._footer(period)}');

    await SharePlus.instance.share(ShareParams(
      text: buffer.toString(),
      subject: SavyitShareCopy.visualReportSubject(period),
    ));
  }

  /// Shares a specific sector breakdown.
  static Future<void> shareSectorBreakdown({
    required String category,
    required double amount,
    required double totalOutflow,
    required List<Transaction> transactions,
    String currencySymbol = '₹',
  }) async {
    final cf = _currencyFmt(currencySymbol);
    final buffer = StringBuffer();
    final percentage = (amount / totalOutflow * 100).toStringAsFixed(1);

    buffer.writeln(SavyitShareCopy.sectorHeader(category));
    buffer.writeln(
        'Spent here: ${cf.format(amount)} ($percentage% of outflow)');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('\nTop moves in $category:');

    final topTxns = transactions.take(10).toList();
    for (var txn in topTxns) {
      final dateStr = DateFormat('dd MMM').format(txn.date);
      buffer.writeln(
          '▸ $dateStr · ${txn.merchant} — ${cf.format(txn.amount)}');
    }

    if (transactions.length > 10) {
      buffer.writeln('…and ${transactions.length - 10} more plot twists.');
    }

    buffer.writeln('\n${SavyitShareCopy._footer(category)}');

    await SharePlus.instance.share(ShareParams(
      text: buffer.toString(),
      subject: _pickSubject(category),
    ));
  }

  static String _pickSubject(String category) =>
      SavyitShareCopy._pick(category, [
        'Savyit sector tea: $category',
        '$category spending — caught in 4K (Savyit)',
        'Where my rupees went: $category',
      ]);

  /// Shares a captured image file.
  static Future<void> shareImage({
    required File imageFile,
    required String subject,
    String? text,
  }) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(imageFile.path)],
      subject: subject,
      text: text,
    ));
  }

  /// Shares a generic file (like CSV).
  static Future<void> shareFile({
    required File file,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      subject: subject,
      text: text,
    ));
  }
}
