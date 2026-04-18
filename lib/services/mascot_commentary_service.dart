// lib/services/mascot_commentary_service.dart
// Context-aware buddy lines for Home; avoids recent repeats via [avoidRecentLines].

import '../models/mascot_dna.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import 'stats_service.dart';

class MascotCommentary {
  final MascotMood mood;
  final String line;

  const MascotCommentary({
    required this.mood,
    required this.line,
  });

  static MascotCommentary fromProvider(
    TransactionProvider p, {
    MascotDna? buddy,
    List<String> avoidRecentLines = const [],
  }) {
    final txns = p.activityVisible;
    final stats = StatsService.compute(txns);
    final nick = _nick(buddy?.name);
    final avoidNorm = avoidRecentLines
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    if (txns.isEmpty) {
      return MascotCommentary(
        mood: MascotMood.sleeping,
        line: _pickAvoid(_sleeping(nick), p, avoidNorm, 11),
      );
    }

    if (stats.totalCredit <= 0) {
      if (stats.totalDebit <= 0) {
        return MascotCommentary(
          mood: MascotMood.sleeping,
          line: _pickAvoid(_sleeping(nick), p, avoidNorm, 12),
        );
      }
      return MascotCommentary(
        mood: MascotMood.chill,
        line: _pickAvoid(_noIncome, p, avoidNorm, 13),
      );
    }

    final ratio = stats.totalDebit / stats.totalCredit;
    var mood = moodFromBudgetPct(ratio);
    final savingsRate =
        (stats.totalCredit - stats.totalDebit) / stats.totalCredit;

    if (savingsRate >= 0.32 && ratio < 0.55) {
      mood = MascotMood.celebrating;
    }

    final reviewCount = txns.where((t) => t.categoryNeedsReview).length;
    if (reviewCount >= 2) {
      final lines = _reviewMany(reviewCount);
      return MascotCommentary(
        mood: mood,
        line: _pickAvoid(lines, p, avoidNorm, reviewCount),
      );
    }
    if (reviewCount == 1) {
      return MascotCommentary(
        mood: mood,
        line: _pickAvoid(_reviewOne, p, avoidNorm, 1),
      );
    }

    final big = _biggestDebit(txns);
    if (big != null && stats.totalDebit > 0) {
      final share = big.amount / stats.totalDebit;
      if (share >= 0.28 && big.amount >= 350) {
        final m = _trimMerchant(big.merchant);
        final lines = _bigPurchase(m, nick);
        return MascotCommentary(
          mood: mood,
          line: _pickAvoid(lines, p, avoidNorm, m.hashCode),
        );
      }
    }

    if (stats.sectors.isNotEmpty) {
      final top = stats.sectors.first;
      if (top.percentage >= 0.5 && stats.totalDebit >= 1500) {
        final lines = _sectorLead(top.name);
        return MascotCommentary(
          mood: mood,
          line: _pickAvoid(lines, p, avoidNorm, top.name.hashCode),
        );
      }
    }

    if (savingsRate >= 0.22 && ratio < 0.62) {
      return MascotCommentary(
        mood: mood,
        line: _pickAvoid(_saver(nick), p, avoidNorm, 20),
      );
    }

    if (ratio >= 1.0) {
      return MascotCommentary(
        mood: mood,
        line: _pickAvoid(_overspent(nick), p, avoidNorm, 30),
      );
    }
    if (ratio >= 0.8) {
      return MascotCommentary(
        mood: mood,
        line: _pickAvoid(_stressed, p, avoidNorm, 31),
      );
    }
    if (ratio >= 0.5) {
      return MascotCommentary(
        mood: mood,
        line: _pickAvoid(_chill, p, avoidNorm, 32),
      );
    }
    if (mood == MascotMood.celebrating) {
      return MascotCommentary(
        mood: mood,
        line: _pickAvoid(_celebrate(nick), p, avoidNorm, 40),
      );
    }
    return MascotCommentary(
      mood: mood,
      line: _pickAvoid(_thriving(nick), p, avoidNorm, 41),
    );
  }

  static String? _nick(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return null;
    final first = t.split(RegExp(r'\s+')).first;
    if (first.length > 14) return '${first.substring(0, 12)}…';
    return first;
  }

  static Transaction? _biggestDebit(List<Transaction> txns) {
    final debits = txns.where((t) => t.isDebit).toList();
    if (debits.isEmpty) return null;
    debits.sort((a, b) => b.amount.compareTo(a.amount));
    return debits.first;
  }

  static String _trimMerchant(String m) {
    final t = m.trim();
    if (t.length <= 18) return t;
    return '${t.substring(0, 16)}…';
  }

  static int _salt(TransactionProvider p, int extra) {
    return p.buddyBubbleSignal ^
        p.stats.totalCount ^
        p.rangeLabel.hashCode ^
        p.transactions.length ^
        extra ^
        0x9e3779b9;
  }

  /// Prefer a line not in [avoidNorm]; fall back to a rotated pick if all match.
  static String _pickAvoid(
    List<String> lines,
    TransactionProvider p,
    Set<String> avoidNorm,
    int extra,
  ) {
    if (lines.isEmpty) return _pickAvoid(_fallbackAny, p, avoidNorm, extra + 99);
    final n = lines.length;
    final start = _salt(p, extra).abs() % n;
    for (var k = 0; k < n; k++) {
      final line = lines[(start + k) % n];
      if (!avoidNorm.contains(line.trim().toLowerCase())) return line;
    }
    return lines[(start + 1 + p.buddyBubbleSignal) % n];
  }

  static List<String> _reviewMany(int c) => [
        '$c transactions are still filed under “Other”—want to name them properly?',
        'I count $c uncategorized spends. Future-you will thank present-you for labels.',
        '$c mystery rows in “Other.” Think of it as a mini filing party.',
        '“Other” is holding $c transactions hostage. Negotiate with a category?',
        '$c spends need real homes—not the junk drawer category.',
        'Untagged squad: $c items. A two-minute sort beats spreadsheet chaos later.',
        '$c lines still say “Other.” I’m not mad, just… architecturally concerned.',
      ];

  static const _reviewOne = [
    'One spend is squatting in “Other.” Evict it with a category?',
    'Solo mystery transaction in “Other”—give it a name, any name.',
    'There’s a lone “Other” entry waving for attention.',
    'Single uncategorized charge: low effort, high clarity if you tag it.',
    'One transaction is playing incognito. Unmask it with a category.',
    'A wild “Other” appears! It’s weak to the Label button.',
    'Just one straggler in “Other.” You’ve got this.',
    'One receipt is shy—still labeled “Other.” Say hi with a sector.',
  ];

  static List<String> _bigPurchase(String m, String? nick) => [
        'That $m charge carried the week—hope it was worth it!',
        'Big swing at $m. No judgment, just math with feelings.',
        if (nick != null) '$nick is side-eyeing that $m receipt…',
        'Whoa—$m ate a chunky slice of this period’s spend.',
        '$m showed up loud on the ledger. Hope it sparkled.',
        'Plot twist: $m was the budget boss this stretch.',
        'If spending were a band, $m just took the solo.',
        '$m: not subtle. Respect the confidence, question the burn rate?',
        'That $m line item has main-character energy.',
        'We need to talk about $m… lovingly, but firmly.',
      ];

  static List<String> _sectorLead(String sector) => [
        '$sector is basically the lead actor in your spending story.',
        '$sector’s eating the biggest slice of the pie chart—star power.',
        'Your wallet and $sector are in a serious relationship this period.',
        '$sector invoices called; they said they’re trending.',
        'If dollars were votes, $sector just won the primary.',
        '$sector: top biller. Crown optional, awareness mandatory.',
        'Spending spotlight is on $sector—cue dramatic lighting.',
        '$sector carried the team—whether you meant it to or not.',
        'The “where did it go?” answer is increasingly: $sector.',
        '$sector isn’t judging you, but the bar chart might be.',
      ];

  static List<String> _sleeping(String? nick) => [
        if (nick != null)
          '$nick is napping until some transactions show up.'
        else
          'I’m napping until some transactions show up.',
        'Quiet wallet energy—import SMS or log something?',
        'No data yet. Tap add and wake me up.',
        'Still waiting for your money story to start.',
        'Empty ledger, full potential. Your move!',
        'Crickets and coins—add a transaction to break the silence.',
        'I’m ready to roast… I mean, review your spends. Feed me data?',
        'No rows, no drama. Yet.',
        'This screen is peaceful. Too peaceful. Import something?',
        'Future charts need present transactions. Hint hint.',
      ];

  static const _noIncome = [
    'Spending without inflows this period—ghost income?',
    'Debits but no credits here—add salary or transfers?',
    'One-way street: money’s leaving but not arriving (in this range).',
    'Outflows only—did income land outside this window?',
    'Credits are MIA; debits are not. Timeline check?',
    'Income didn’t RSVP to this date range—spends did anyway.',
    'Looks like outflow karaoke with no inflow backup singers.',
  ];

  static List<String> _overspent(String? nick) => [
        'Outflow beat inflow—your budget is doing cartwheels (bad kind).',
        if (nick != null)
          '$nick suggests a tiny pause before the next swipe.'
        else
          'Maybe a tiny pause before the next swipe?',
        'We’re net negative for this window. Deep breath, then a plan?',
        'Spending sprint finished ahead of income. Time to regroup.',
        'Income waved; spending didn’t wait. Reset mode?',
        'The red side of the ledger is winning this round.',
        'Wallet on overtime—give it a break next week?',
        'You outran your inflows. Cool story, expensive ending.',
        'Spending went feral. Tame it with one small cut?',
        'That ratio hurts—but it’s fixable. Small steps.',
        'Oof era activated. Brighter era loading…',
        'Numbers went spicy. Cool them with a no-spend day?',
      ];

  static const _stressed = [
    'You’re riding close to the edge—small trims help a lot.',
    'Spend is nibbling most of what came in. Watch the leaks?',
    'Tightrope mode: a little less “treat yourself” goes far.',
    'Most of income walked out the door—invite some back (savings)?',
    'You’re in the yellow zone—caution, not panic.',
    'Budget’s doing yoga: stretched. Loosen one category?',
    'High spend velocity—air brakes exist for a reason.',
    'The margin for surprises is thin. Maybe thicken it?',
    'Close call energy—one calm week changes the vibe.',
    'Not broke, not comfy—tweak one habit and breathe easier.',
  ];

  static const _chill = [
    'Room left in the tank—not bad at all.',
    'Balanced-ish. You’re not hero broke, not hero rich—human.',
    'Steady cruising. I’ll take it.',
    'Spend and income are on speaking terms. Healthy.',
    'Middle path unlocked—neither feast nor famine.',
    'You’re steering, not swerving. Nice.',
    'Budget has elbow room. Rare flex.',
    'Sustainable-ish. Keep the vibe.',
    'Nothing flashy, nothing scary—solid B+ adulting.',
    'Calm spreadsheet weather. Enjoy it.',
  ];

  static List<String> _thriving(String? nick) => [
        'You’re keeping more than you’re leaking. That’s the game!',
        if (nick != null) '$nick is doing a tiny victory wiggle.'
        else
          'Tiny victory wiggle: you’re under half on spend vs income.',
        'Savings lane unlocked for this period. Nice.',
        'Income’s winning—keep that energy.',
        'Leakage low, morale high. Science.',
        'You’re ahead of the burn rate. Rare air!',
        'Money stayed home more than it wandered. Love that.',
        'Under half spent—quiet flex, loud results.',
        'That’s the discipline playlist on shuffle.',
        'Your future self is nodding approvingly.',
  ];

  static List<String> _celebrate(String? nick) => [
        if (nick != null)
          '$nick is throwing confetti—you’re stacking serious surplus!'
        else
          'Confetti mode: you’re stacking serious surplus!',
        'Chef’s kiss—savings rate looking delicious.',
        'You’re basically a dragon hoarding… responsibly.',
        'Income showed up and you didn’t spend it all. Legend.',
        'Surplus szn. Protect it like Wi‑Fi password.',
        'That savings rate could get its own fan account.',
        'You’re leaving money behind on purpose—in the good way.',
        'Wallet: fed. Impulses: managed. Vibes: immaculate.',
        'Stack mode engaged. Don’t forget to enjoy a little, too.',
        'Numbers so pretty I’d frame them (digitally).',
  ];

  static List<String> _saver(String? nick) => [
        'Saving streak energy—I see you.',
        if (nick != null)
          '$nick approves of this “money stays” situation.'
        else
          'Solid “money stays” situation right here.',
        'More cushion than crunch. Love that.',
        'You’re paying future-you first. Polite.',
        'Cushion growing—emergency fund says thanks.',
        'Income minus noise equals progress. You’re there.',
        'That’s intentional restraint with style.',
        'Savings muscle flexed. Protein: discipline.',
        'Quiet wealth-building hours. Respect.',
  ];

  static const _fallbackAny = [
    'Still here, still judging… gently.',
    "Numbers updated—I'm doing mental cartwheels (controlled).",
    'Fresh data smells like possibility. Or receipts.',
    'Ledger changed; my commentary machine whirred happily.',
    'New math dropped. I have opinions.',
    'Tap around—I’ll keep an eye on the totals.',
    'Your story moved forward one transaction at a time.',
  ];
}
