// lib/screens/overview_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/transaction_provider.dart';
import '../services/stats_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../services/sms_service.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../widgets/major_spends_deck.dart';
import '../widgets/money_rhythm_card.dart';
import '../widgets/mint_tide_hero_shell.dart';
import '../widgets/manual_transaction_sheet.dart';
import '../widgets/pdf_mode_sheet.dart';
import '../widgets/blob_mascot.dart';
import '../widgets/confetti_overlay.dart';
import '../models/mascot_dna.dart';
import '../services/mascot_commentary_service.dart';
import 'profile_screen.dart';
import '../ui/fcl/sleek_plan_hero_frame.dart';
import '../ui/savyit/index.dart';

class OverviewScreen extends StatefulWidget {
  final VoidCallback? onViewAll;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenBudgets;
  final VoidCallback? onOpenGroupSplit;

  const OverviewScreen({
    super.key,
    this.onViewAll,
    this.onOpenPlan,
    this.onOpenBudgets,
    this.onOpenGroupSplit,
  });

  @override
  State<OverviewScreen> createState() => OverviewScreenState();
}

class OverviewScreenState extends State<OverviewScreen>
    with WidgetsBindingObserver {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;
  String _shareLoadingBlurb = '';
  String _userName = '';
  MascotDna? _mascotDna;
  int _prevTxnCount = 0;
  bool _milestoneCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TransactionProvider>().requestBuddyBubble();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<TransactionProvider>().requestBuddyBubble();
    }
  }

  void _loadUser() async {
    final name = await StorageService.getUserName();
    final dna = await StorageService.loadMascotDna();
    if (!mounted) return;
    setState(() {
      _userName = name ?? '';
      _mascotDna = dna;
    });
    if (mounted) {
      context.read<TransactionProvider>().requestBuddyBubble();
    }
  }

  /// Call after settings/profile may have changed stored buddy DNA or display name.
  void reloadUserAndBuddy() => _loadUser();

  Future<void> _checkMilestones() async {
    final fired = await StorageService.isMilestoneFired('first_import');
    if (!fired && mounted) {
      await StorageService.markMilestone('first_import');
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ConfettiOverlay.burst(context);
    }
  }

  Future<void> _handleShareReport(
      BuildContext context, TransactionProvider p) async {
    if (_isSharing) return;
    setState(() {
      _isSharing = true;
      _shareLoadingBlurb = SavyitShareCopy.loadingBlurb();
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not find render object');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Could not encode image');

      final buffer = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/savyit_report_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(buffer);

      final stats = p.stats;
      final period = p.rangeLabel;

      final textReport = SavyitShareCopy.visualReportCaption(
        period: period,
        inflow: p.formatAmount(stats.totalCredit),
        outflow: p.formatAmount(stats.totalDebit),
        net: p.formatAmount(stats.netBalance, showSign: true),
      );

      await ShareService.shareImage(
        imageFile: file,
        subject: SavyitShareCopy.visualReportSubject(period),
        text: textReport,
      );
    } catch (e) {
      debugPrint('Error sharing report: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Failed to generate visual report: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    final stats = p.stats;

    // Schedule first-import milestone check
    if (p.transactions.isNotEmpty && _prevTxnCount == 0 && !_milestoneCheckScheduled) {
      _milestoneCheckScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkMilestones();
      });
    }
    _prevTxnCount = p.transactions.length;

    if (p.state == LoadState.loading) {
      return _LoadingState(p: p);
    }

    if (p.state == LoadState.permissionDenied) return _PermissionDenied(p: p);
    if (p.state == LoadState.error) return _ErrorState(p: p);
    if (p.transactions.isEmpty) return _Empty(p: p);

    final net = stats.netBalance;
    final savingsRate = stats.totalCredit > 0
        ? ((stats.totalCredit - stats.totalDebit) / stats.totalCredit * 100)
            .clamp(-100, 100)
        : 0.0;

    final majorSpends = p.activityVisible.where((t) => t.isDebit).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final topMajorSpends = majorSpends.take(5).toList();

    return RefreshIndicator(
      color: AppColors.chartStrokeOnCard,
      onRefresh: p.load,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          // Home shell already uses an app bar that includes the status inset.
          top: AppSpacing.lg,
          bottom: AppSpacing.scrollBottomDockClearance,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting — lavender block + black stroke (neo), blends with page gradient.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: _GreetingRow(
                userName: _userName,
                mascotDna: _mascotDna,
              ),
            ),
            SizedBox(height: AppSpacing.xl),

            // Balance hero (padded; shares lavender→cream story with page gradient)
            MintTideHeroShell(
              repaintBoundaryKey: _boundaryKey,
              child: _BalanceHeroCard(
                balance: net,
                income: stats.totalCredit.toDouble(),
                expenses: stats.totalDebit.toDouble(),
                savingsRate: savingsRate.toDouble(),
                transactionCount: stats.totalCount,
                formatAmount: p.formatAmount,
              ),
            ),

            SizedBox(height: AppSpacing.xl),

            // Remaining content with horizontal padding
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions Row
                  _QuickActions(
                    p: p,
                    onOpenPlan: widget.onOpenPlan,
                    onOpenBudgets: widget.onOpenBudgets,
                    onOpenGroupSplit: widget.onOpenGroupSplit,
                  ),

                  SizedBox(height: AppSpacing.xl),

                  const MoneyRhythmCard(),

                  SizedBox(height: AppSpacing.xl),

                  if (topMajorSpends.isNotEmpty) ...[
                    MajorSpendsDeck(
                      spends: topMajorSpends,
                      periodLabel: p.rangeLabel,
                      formatInr: p.formatAmount,
                    ),
                    SizedBox(height: AppSpacing.xl),
                  ],

                  // Recent Activity Section
                  _RecentActivity(
                    transactions: p.activityVisible.take(4).toList(),
                    onViewAll: widget.onViewAll,
                  ),

                  SizedBox(height: AppSpacing.xl),

                  // Quick Guide Section
                  _QuickGuide(onReturnedFromSettings: reloadUserAndBuddy),

                  SizedBox(height: AppSpacing.xxxl),

                  // Charts Section
                  if (stats.cumulative.length >= 3 ||
                      stats.sectors.isNotEmpty) ...[
                    Text(
                      'Insights',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: AppSpacing.lg),
                    if (stats.cumulative.length >= 3)
                      _ChartSection(
                        title: 'Balance Trend',
                        subtitle: 'Your balance over time',
                        child: _CashflowChart(points: stats.cumulative),
                      ),
                    if (stats.sectors.isNotEmpty) ...[
                      SizedBox(height: AppSpacing.lg),
                      _ChartSection(
                        title: 'Spending by Category',
                        subtitle: 'Where your money goes',
                        child: _SectorChart(sectors: stats.sectors),
                      ),
                    ],
                  ],

                  SizedBox(height: AppSpacing.xxl),

                  // Share Button
                  Center(
                    child: _isSharing
                        ? _ShareLoadingIndicator(line: _shareLoadingBlurb)
                        : _ShareButton(
                            title: SavyitShareCopy.heroShareTitle(p.rangeLabel),
                            subtitle: SavyitShareCopy.heroShareSubtitle(
                                p.rangeLabel),
                            onTap: () => _handleShareReport(context, p)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hey + name + mood — wrapped in lavender neo card when not monochrome.
class _GreetingRow extends StatefulWidget {
  final String userName;
  final MascotDna? mascotDna;

  const _GreetingRow({
    required this.userName,
    required this.mascotDna,
  });

  @override
  State<_GreetingRow> createState() => _GreetingRowState();
}

class _GreetingRowState extends State<_GreetingRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _bubbleCtrl;
  late Animation<double> _bubbleAnim;
  Timer? _dismissTimer;
  Timer? _refreshDebounce;
  TransactionProvider? _attachedProvider;
  late VoidCallback _providerListener;
  int _buddySignalLast = 0;

  MascotMood _buddyMood = MascotMood.curious;
  String _buddyLine = '';

  static const _showDuration = Duration(milliseconds: 340);
  static const _visibleDuration = Duration(seconds: 10);
  static const _refreshDebounceMs = 320;

  @override
  void initState() {
    super.initState();
    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: _showDuration,
    );
    _bubbleAnim = CurvedAnimation(
      parent: _bubbleCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _attachedProvider = context.read<TransactionProvider>();
    _buddySignalLast = _attachedProvider!.buddyBubbleSignal;
    _providerListener = () {
      if (!mounted || _attachedProvider == null) return;
      final now = _attachedProvider!.buddyBubbleSignal;
      if (now != _buddySignalLast) {
        _buddySignalLast = now;
        _queueBuddyRefresh();
      }
    };
    _attachedProvider!.addListener(_providerListener);
    _queueBuddyRefresh();
  }

  bool get _shouldShowBubble =>
      widget.mascotDna != null && _buddyLine.trim().isNotEmpty;

  void _queueBuddyRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce =
        Timer(const Duration(milliseconds: _refreshDebounceMs), () {
      if (!mounted) return;
      final sig = _attachedProvider?.buddyBubbleSignal ?? 0;
      _applyBuddyCommentary(sig);
    });
  }

  Future<void> _applyBuddyCommentary(int capturedSignal) async {
    if (!mounted || widget.mascotDna == null) return;
    final p = context.read<TransactionProvider>();
    if (p.transactions.isEmpty) {
      if (!mounted) return;
      setState(() {
        _buddyLine = '';
        _buddyMood = MascotMood.sleeping;
      });
      _dismissTimer?.cancel();
      _bubbleCtrl.reverse();
      return;
    }

    final history = await StorageService.getBuddyLineHistory();
    final commentary = MascotCommentary.fromProvider(
      p,
      buddy: widget.mascotDna,
      avoidRecentLines: history,
    );
    if (commentary.line.trim().isNotEmpty) {
      await StorageService.recordBuddyLineShown(commentary.line);
    }
    if (!mounted ||
        (_attachedProvider?.buddyBubbleSignal ?? 0) != capturedSignal) {
      return;
    }

    setState(() {
      _buddyLine = commentary.line;
      _buddyMood = commentary.mood;
    });
    _playBubbleCycle();
  }

  void _playBubbleCycle() {
    if (!_shouldShowBubble || !mounted) return;
    _dismissTimer?.cancel();
    _bubbleCtrl.forward(from: 0);
    _dismissTimer = Timer(_visibleDuration, () {
      if (mounted) _bubbleCtrl.reverse();
    });
  }

  @override
  void didUpdateWidget(_GreetingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mascotDna != widget.mascotDna ||
        oldWidget.userName != widget.userName) {
      _queueBuddyRefresh();
    }
  }

  @override
  void dispose() {
    _attachedProvider?.removeListener(_providerListener);
    _dismissTimer?.cancel();
    _refreshDebounce?.cancel();
    _bubbleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _greetingColumn(context);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: copy),
        if (widget.mascotDna != null) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BlobMascot(
                dna: widget.mascotDna!,
                mood: _buddyMood,
                size: 88,
                contrastPlate: true,
              ),
              if (_shouldShowBubble) ...[
                const SizedBox(height: 2),
                AnimatedBuilder(
                  animation: _bubbleAnim,
                  builder: (context, child) {
                    final t = _bubbleAnim.value;
                    final hf = t <= 0.008 ? 0.0 : t;
                    return ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: hf,
                        child: Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * -18),
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 188,
                    child: _MascotSpeechBubble(text: _buddyLine),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
    if (AppColors.isMonochrome) {
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: AppDecorations.greetingMono,
        child: row,
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: NeoPopDecorations.card(
        fill: AppColors.greetingLavender,
        radius: AppRadius.xl,
        shadowOffset: 4,
      ),
      child: row,
    );
  }

  Widget _greetingColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'hey,',
          style: GoogleFonts.instrumentSerif(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            height: 1.2,
          ),
        ),
        Text(
          widget.userName.isNotEmpty ? widget.userName : 'there',
          style: GoogleFonts.instrumentSerif(
            fontSize: 42,
            color: AppColors.textMain,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        if (widget.mascotDna != null)
          _MoodChip(mood: _buddyMood)
        else
          Text(
            "Here's your finance summary",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
      ],
    );
  }
}

/// Speech bubble under the mascot; tail points up at the buddy.
class _MascotSpeechBubble extends StatelessWidget {
  final String text;

  const _MascotSpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final mono = AppColors.isMonochrome;
    final fill = mono ? AppColors.surface2 : AppColors.surface;
    final stroke = mono ? AppColors.border.withValues(alpha: 0.85) : AppNeoColors.strokeBlack;
    final strokeW = mono ? 1.25 : 1.5;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        CustomPaint(
          size: const Size(18, 10),
          painter: _SpeechTailPainter(
            fill: fill,
            stroke: stroke,
            strokeWidth: strokeW,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: DecoratedBox(
            decoration: mono
                ? BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: stroke, width: strokeW),
                  )
                : BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: stroke, width: strokeW),
                    boxShadow: NeoPopDecorations.hardShadow(2),
                  ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeechTailPainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  _SpeechTailPainter({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final path = Path()
      ..moveTo(cx - w * 0.38, h)
      ..lineTo(cx, 0)
      ..lineTo(cx + w * 0.38, h)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeechTailPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.stroke != stroke ||
      oldDelegate.strokeWidth != strokeWidth;
}

// Loading State
class _LoadingState extends StatelessWidget {
  final TransactionProvider p;
  const _LoadingState({required this.p});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedLoading03,
                size: 32,
                color: AppColors.isMonochrome
                    ? AppColors.primary
                    : AppColors.iconOnLight,
              ),
            ),
            SizedBox(height: AppSpacing.xxl),
            Text(
              p.progressLabel,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Analyzing your transactions...',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (p.progressTotal > 0) ...[
              SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: p.progressCurrent / p.progressTotal,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Hero Balance Card — Premium Dark Gradient
class _BalanceHeroCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expenses;
  final double savingsRate;
  final int transactionCount;
  final String Function(double amount, {bool showSign}) formatAmount;

  const _BalanceHeroCard({
    required this.balance,
    required this.income,
    required this.expenses,
    required this.savingsRate,
    required this.transactionCount,
    required this.formatAmount,
  });

  String _moodEmoji() {
    if (AppColors.isMonochrome) return '';
    return income >= expenses ? '😄' : '😟';
  }

  String _moodText() {
    if (income >= expenses) {
      return 'Money buddy is happy: receiving is beating spending.';
    }
    return 'Money buddy is sad: spending is higher than receiving.';
  }

  @override
  Widget build(BuildContext context) {
    return SleekPlanHeroFrame(
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
            // Premium background gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.isMonochrome
                      ? AppGradients.monoBalanceHero
                      : AppGradients.balanceHeroFill,
                ),
              ),
            ),
            // Soft wash — color mode only (mono hero already has metallic fill).
            if (!AppColors.isMonochrome)
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.greetingLavender.withValues(alpha: 0.45),
                        AppColors.greetingLavender.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),

            // Brand Corner (Savyit)
            Positioned(
              top: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lens_blur_rounded,
                        size: 14,
                        color: AppColors.isMonochrome
                            ? AppColors.primary
                            : AppColors.primaryDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SAVYIT',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.isMonochrome
                              ? AppColors.primary
                              : AppColors.primaryDark,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Financial Snapshot',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            Column(
              children: [
                // Main Balance Section
                Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.xxl,
                      AppSpacing.xxl + 12, AppSpacing.xxl, AppSpacing.xxl),
                  child: Column(
                    children: [
                      Text(
                        'CURRENT BALANCE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain.withValues(alpha: 0.4),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        formatAmount(balance),
                        style: GoogleFonts.inter(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMain,
                          letterSpacing: -2.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Premium Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: (savingsRate >= 0
                                    ? AppColors.primary
                                    : AppColors.red)
                                .withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (savingsRate >= 0
                                      ? AppColors.primary
                                      : AppColors.red)
                                  .withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              savingsRate >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 14,
                              color: savingsRate >= 0
                                  ? (AppColors.isMonochrome
                                      ? AppColors.primary
                                      : AppColors.primaryDark)
                                  : AppColors.red,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${savingsRate.abs().toStringAsFixed(0)}% ${savingsRate >= 0 ? 'SAVED' : 'OVER BUDGET'}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMain,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!AppColors.isMonochrome) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.86),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: (income >= expenses
                                      ? AppColors.primary
                                      : AppColors.red)
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            '${_moodEmoji()} ${_moodText()}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Stats footer — warm neutral tray (same family as page lower wash).
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.isMonochrome
                        ? AppColors.primarySoft.withValues(alpha: 0.4)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.isMonochrome
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppNeoColors.strokeBlack.withValues(alpha: 0.12),
                      width: AppColors.isMonochrome ? 1 : 1.5,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _HeroFooterItem(
                            label: 'INCOME',
                            value: formatAmount(income),
                            color: AppColors.primary,
                            icon: Icons.south_west_rounded,
                          ),
                        ),
                        _HeroKpiDivider(),
                        Expanded(
                          child: _HeroFooterItem(
                            label: 'EXPENSES',
                            value: formatAmount(expenses),
                            color: AppColors.red,
                            icon: Icons.north_east_rounded,
                          ),
                        ),
                        _HeroKpiDivider(),
                        Expanded(
                          child: _HeroFooterItem(
                            label: 'TXNS',
                            value: '$transactionCount',
                            color: AppColors.textMain,
                            icon: Icons.receipt_long_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
        ],
      ),
    );
  }
}

/// Vertical rule between hero KPI columns. Uses [VerticalDivider] instead of
/// [ShadSeparator.vertical] so layout stays finite inside scrollables (unbounded height).
class _HeroKpiDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      indent: 0,
      endIndent: 0,
      color: AppNeoColors.strokeBlack.withValues(alpha: 0.12),
    );
  }
}

class _HeroFooterItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _HeroFooterItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _heroKpiChipFill(color),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 12, color: _heroKpiIconColor(color)),
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: label == 'INCOME' ? AppNeoColors.shadowInk : color,
          ),
        ),
      ],
    );
  }
}

Color _heroKpiIconColor(Color accent) {
  if (AppColors.isMonochrome) return accent;
  if (accent == AppColors.primary ||
      accent == AppColors.primaryLight ||
      accent == AppNeoColors.lime) {
    return AppColors.iconOnLight;
  }
  return accent;
}

Color _heroKpiChipFill(Color accent) {
  if (AppColors.isMonochrome) return accent.withValues(alpha: 0.2);
  if (accent == AppColors.primary ||
      accent == AppColors.primaryLight ||
      accent == AppNeoColors.lime) {
    return AppNeoColors.lime.withValues(alpha: 0.32);
  }
  return accent.withValues(alpha: 0.2);
}

// Chart Section Container
class _ChartSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: AppSpacing.xs),
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// Share Button
class _ShareButton extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  const _ShareButton({
    required this.onTap,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isNeo = !AppColors.isMonochrome;
    final fg = isNeo ? AppNeoColors.ink : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: isNeo
              ? NeoPopDecorations.card(
                  fill: AppNeoColors.lime,
                  radius: AppRadius.lg,
                  shadowOffset: 6,
                )
              : BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.md,
                ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedShare01,
                    color: fg,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: fg,
                        letterSpacing: -0.35,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: fg.withValues(alpha: isNeo ? 0.82 : 0.9),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareLoadingIndicator extends StatelessWidget {
  final String line;

  const _ShareLoadingIndicator({required this.line});

  @override
  Widget build(BuildContext context) {
    final msg = line.trim().isEmpty ? 'Baking pixels…' : line;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: !AppColors.isMonochrome
          ? NeoPopDecorations.card(
              fill: AppColors.surface2,
              radius: AppRadius.md,
              shadowOffset: 3,
            )
          : BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.chartStrokeOnCard,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              msg,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowChart extends StatelessWidget {
  final List<CumulativePoint> points;
  const _CashflowChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox();

    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.balance))
        .toList();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.chartStrokeOnCard,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (index == spots.length - 1) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: AppColors.chartStrokeOnCard,
                    strokeWidth: 2,
                    strokeColor: AppColors.surface,
                  );
                }
                return FlDotCirclePainter(radius: 0, color: Colors.transparent);
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.chartStrokeOnCard.withValues(alpha: 0.12),
            ),
          ),
        ],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY == 0) ? 1.0 : (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: minY - padding,
        maxY: maxY + padding,
      ),
    );
  }
}

class _SectorChart extends StatelessWidget {
  final List<SectorStat> sectors;
  const _SectorChart({required this.sectors});

  @override
  Widget build(BuildContext context) {
    if (sectors.isEmpty) return const SizedBox();

    final colors = AppColors.sectorColors;
    final total = sectors.fold(0.0, (sum, s) => sum + s.amount);

    return Row(
      children: [
        // Donut Chart
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              sections: sectors
                  .asMap()
                  .entries
                  .map((e) => PieChartSectionData(
                        value: e.value.amount,
                        color: colors[e.key % colors.length],
                        radius: 28,
                        showTitle: false,
                      ))
                  .toList(),
              pieTouchData: PieTouchData(enabled: false),
            ),
          ),
        ),
        SizedBox(width: AppSpacing.lg),
        // Legend
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sectors.take(4).toList().asMap().entries.map((e) {
              final sector = e.value;
              final color = colors[e.key % colors.length];
              final percent = total > 0 ? (sector.amount / total * 100) : 0;
              return Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        sector.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${percent.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  final TransactionProvider p;
  const _PermissionDenied({required this.p});

  @override
  Widget build(BuildContext context) {
    final detail = p.debugInfo.trim().isEmpty ? null : p.debugInfo.trim();
    return _StateMessage(
      icon: HugeIcons.strokeRoundedShield01,
      iconColor: AppColors.amber,
      iconBgColor: AppColors.amberLight,
      title: 'SMS access required',
      message:
          'Savyit needs SMS permission to read bank and UPI alerts from your inbox. If you tapped “Don’t allow”, use Open settings below, then enable SMS for this app.',
      diagnosticDetail: detail,
      actions: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: p.load,
              child: const Text('Try again'),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => SmsService.openSettings(),
              child: const Text('Open system settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final TransactionProvider p;
  const _ErrorState({required this.p});

  @override
  Widget build(BuildContext context) {
    final summary = (p.error ?? '').trim().isEmpty
        ? 'Something went wrong while loading or parsing SMS.'
        : p.error!.trim();
    final detail = p.debugInfo.trim().isEmpty ? null : p.debugInfo.trim();
    return _StateMessage(
      icon: HugeIcons.strokeRoundedAlertCircle,
      iconColor: AppColors.red,
      iconBgColor: AppColors.redLight,
      title: 'Couldn’t complete import',
      message:
          '$summary\n\nUse the diagnostics below to see what the app did last. You can copy and share them if you need help.',
      diagnosticDetail: detail,
      actions: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: p.load,
          child: const Text('Try again'),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final dynamic icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String message;
  final String? diagnosticDetail;
  final Widget? actions;

  const _StateMessage({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.message,
    this.diagnosticDetail,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final detail = diagnosticDetail?.trim();
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: HugeIcon(icon: icon, size: 40, color: iconColor),
            ),
            SizedBox(height: AppSpacing.xxl),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
              textAlign: TextAlign.center,
            ),
            if (detail != null && detail.isNotEmpty) ...[
              SizedBox(height: AppSpacing.xl),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Diagnostics',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textMain,
                      ),
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    detail,
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.textMain,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: detail));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Diagnostics copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy diagnostics'),
              ),
            ],
            if (actions != null) ...[
              SizedBox(height: AppSpacing.xxl),
              actions!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final TransactionProvider p;
  const _Empty({required this.p});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl, vertical: AppSpacing.huge),
      child: Column(
        children: [
          // Empty State Header
          Container(
            padding: EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedWallet01,
              size: 48,
              color: AppColors.isMonochrome
                  ? AppColors.primary
                  : AppColors.iconOnLight,
            ),
          ),
          SizedBox(height: AppSpacing.xxl),
          Text(
            'Start Tracking',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Import your transactions to see insights',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xxxl),

          // Import Options
          _ImportOption(
            icon: HugeIcons.strokeRoundedMessage01,
            title: 'Scan SMS',
            subtitle: 'Import from bank messages',
            color: AppColors.primary,
            onTap: p.load,
          ),
          SizedBox(height: AppSpacing.md),
          _ImportOption(
            icon: HugeIcons.strokeRoundedFileAttachment,
            title: 'Import PDF',
            subtitle: 'Upload bank statements',
            color: AppColors.primary,
            onTap: () => _openPdfFlow(context, p),
          ),
          SizedBox(height: AppSpacing.md),
          _ImportOption(
            icon: HugeIcons.strokeRoundedPencilEdit01,
            title: 'Add Manually',
            subtitle: 'Enter transactions by hand',
            color: AppColors.primary,
            onTap: () => _openManualEntry(context, p),
          ),
        ],
      ),
    );
  }

  void _openManualEntry(BuildContext context, TransactionProvider p) async {
    final draft = await showManualTransactionSheet(context);
    if (draft != null) {
      p.addManualTransaction(
        merchant: draft.merchant,
        amount: draft.amount,
        type: draft.type,
        category: draft.category,
        bank: draft.bank,
        date: draft.date,
      );
    }
  }

  void _openPdfFlow(BuildContext context, TransactionProvider p) async {
    final mode = await showPdfChunkModeSheet(context);
    if (mode == null) return;
    p.processPdf(mode: mode);
  }
}

class _ImportOption extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ImportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: AppDecorations.card,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: AppDecorations.iconContainer(color: color),
                child: HugeIcon(
                  icon: icon,
                  color: AppColors.isMonochrome ? color : AppColors.iconOnLight,
                  size: 22,
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final TransactionProvider p;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenBudgets;
  final VoidCallback? onOpenGroupSplit;
  const _QuickActions({
    required this.p,
    this.onOpenPlan,
    this.onOpenBudgets,
    this.onOpenGroupSplit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          if (onOpenBudgets != null) ...[
            _QuickActionTile(
              icon: HugeIcons.strokeRoundedTarget02,
              label: 'Occasion',
              color: AppColors.primary,
              onTap: onOpenBudgets!,
            ),
            SizedBox(width: AppSpacing.md),
          ],
          if (onOpenGroupSplit != null) ...[
            _QuickActionTile(
              icon: HugeIcons.strokeRoundedExchange01,
              label: 'Split',
              color: AppColors.primaryDark,
              onTap: onOpenGroupSplit!,
            ),
            SizedBox(width: AppSpacing.md),
          ],
          _QuickActionTile(
            icon: HugeIcons.strokeRoundedMessage01,
            label: 'Scan SMS',
            color: AppColors.primary,
            onTap: p.load,
          ),
          SizedBox(width: AppSpacing.md),
          _QuickActionTile(
            icon: HugeIcons.strokeRoundedFileAttachment,
            label: 'Upload PDF',
            color: AppColors.primary,
            onTap: () async {
              final mode = await showPdfChunkModeSheet(context);
              if (mode != null) p.processPdf(mode: mode);
            },
          ),
          SizedBox(width: AppSpacing.md),
          _QuickActionTile(
            icon: HugeIcons.strokeRoundedPencilEdit01,
            label: 'Manual',
            color: AppColors.primaryLight,
            onTap: () async {
              final draft = await showManualTransactionSheet(context);
              if (draft != null) {
                p.addManualTransaction(
                  merchant: draft.merchant,
                  amount: draft.amount,
                  type: draft.type,
                  category: draft.category,
                  bank: draft.bank,
                  date: draft.date,
                );
              }
            },
          ),
          if (onOpenPlan != null) ...[
            SizedBox(width: AppSpacing.md),
            _QuickActionTile(
              icon: HugeIcons.strokeRoundedAnalytics01,
              label: 'Plan',
              color: AppColors.primaryDark,
              onTap: onOpenPlan!,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final dynamic icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: AppColors.isMonochrome
            ? BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.6),
                  width: 1,
                ),
                boxShadow: AppShadows.sm,
              )
            : NeoPopDecorations.card(
                fill: AppColors.surface,
                radius: AppRadius.lg,
                shadowOffset: 4,
              ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.isMonochrome
                    ? color.withValues(alpha: 0.1)
                    : AppNeoColors.lime.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
              ),
              child: HugeIcon(
                icon: icon,
                color: AppColors.isMonochrome ? color : AppColors.iconOnLight,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback? onViewAll;
  const _RecentActivity({required this.transactions, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentTextOnSurface,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppDecorations.cardElevated,
          child: Column(
            children: [
              for (var i = 0; i < transactions.length; i++) ...[
                _RecentTxnTile(txn: transactions[i]),
                if (i < transactions.length - 1)
                  Divider(
                    height: 1,
                    color: AppNeoColors.strokeBlack.withValues(alpha: 0.08),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentTxnTile extends StatelessWidget {
  final Transaction txn;
  const _RecentTxnTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: () async {
          final shouldDelete = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Transaction?'),
              content: const Text('Delete this transaction from history?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Delete', style: TextStyle(color: AppColors.red)),
                ),
              ],
            ),
          );
          if (shouldDelete == true && context.mounted) {
            context.read<TransactionProvider>().deleteTransaction(txn.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaction deleted')),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (txn.isCredit ? AppColors.primary : AppColors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: txn.isCredit
                      ? HugeIcons.strokeRoundedArrowUpRight01
                      : HugeIcons.strokeRoundedArrowDownLeft01,
                  color: txn.isCredit
                      ? (AppColors.isMonochrome
                          ? AppColors.primary
                          : AppColors.iconOnLight)
                      : AppColors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.merchant,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      txn.category,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${txn.isCredit ? '+' : '-'}${context.watch<TransactionProvider>().formatAmount(txn.amount)}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: txn.isCredit ? AppColors.primary : AppColors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickGuide extends StatelessWidget {
  const _QuickGuide({required this.onReturnedFromSettings});

  final VoidCallback onReturnedFromSettings;

  void _showGuideDetail(
    BuildContext context, {
    required String title,
    required dynamic icon,
    required Color color,
    required String details,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.sheetChrome,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: HugeIcon(
                      icon: icon,
                      color: AppColors.glyphOnPaleAccent(color),
                      size: 28,
                    ),
                  ),
                  SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.lg),
              Text(
                details,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
              ),
              SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Guide',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            IconButton(
              icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedSettings01,
                  color: AppColors.textMain,
                  size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen()),
                ).then((_) => onReturnedFromSettings());
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _GuideCard(
                icon: HugeIcons.strokeRoundedMessage01,
                title: 'SMS Scan',
                desc: 'Local scan for instant dashboard.',
                color: AppColors.primary,
                onTap: () => _showGuideDetail(
                  context,
                  title: 'SMS Scan',
                  icon: HugeIcons.strokeRoundedMessage01,
                  color: AppColors.primary,
                  details:
                      'Savyit neatly organizes your finances by scanning your bank SMS messages locally on your device.\n\nSince it runs entirely on your phone, no manual entry is required and your sensitive financial messages never leave your device.',
                ),
              ),
              const SizedBox(width: 12),
              _GuideCard(
                icon: HugeIcons.strokeRoundedFileAttachment,
                title: 'PDF Statements',
                desc: 'Upload from GPay or PhonePe.',
                color: AppColors.primaryDark,
                onTap: () => _showGuideDetail(
                  context,
                  title: 'PDF Statements',
                  icon: HugeIcons.strokeRoundedFileAttachment,
                  color: AppColors.primaryDark,
                  details:
                      'You can upload your credit card or bank statements (usually PDF format) directly into the app.\n\nSavyit will parse them securely and automatically categorize your spending patterns to give you a deep financial check-up.',
                ),
              ),
              const SizedBox(width: 12),
              _GuideCard(
                icon: HugeIcons.strokeRoundedPencilEdit01,
                title: 'Manual Log',
                desc: 'Log cash or private spends.',
                color: AppColors.primaryLight,
                onTap: () => _showGuideDetail(
                  context,
                  title: 'Manual Log',
                  icon: HugeIcons.strokeRoundedPencilEdit01,
                  color: AppColors.primaryLight,
                  details:
                      'For cash transactions, split bills, or anything not in your messages, you can log them manually.\n\nYou have full control over the categories, labels, and exact dates for these custom entries.',
                ),
              ),
              const SizedBox(width: 12),
              _GuideCard(
                icon: HugeIcons.strokeRoundedAnalytics01,
                title: '100% Private',
                desc: 'No DB. Data stays on device.',
                color: AppColors.amber,
                onTap: () => _showGuideDetail(
                  context,
                  title: '100% Private Ecosystem',
                  icon: HugeIcons.strokeRoundedAnalytics01,
                  color: AppColors.amber,
                  details:
                      'We believe your financial data belongs to you. Savyit does not have a central database where your transactions are stored.\n\nEverything is processed and saved locally on your device for absolute privacy and security.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoodChip extends StatelessWidget {
  final MascotMood mood;
  const _MoodChip({required this.mood});

  @override
  Widget build(BuildContext context) => SavyitChip(
    label: mood.label,
    variant: SavyitChipVariant.mood,
    moodColor: mood.chipColor,
  );
}

class _GuideCard extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  const _GuideCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          decoration: AppColors.isMonochrome
              ? BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: AppShadows.sm,
                )
              : NeoPopDecorations.card(
                  fill: AppColors.surface,
                  radius: 20,
                  shadowOffset: 4,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HugeIcon(
                  icon: icon,
                  color: AppColors.glyphOnPaleAccent(color),
                  size: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
