// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/transaction_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_background.dart';
import '../widgets/pdf_mode_sheet.dart';
import '../widgets/manual_transaction_sheet.dart';
import '../widgets/profile_prompt_sheet.dart';
import '../widgets/category_review_sheet.dart';
import 'overview_screen.dart';
import 'daywise_screen.dart';
import 'sectors_screen.dart';
import 'transactions_screen.dart';
import 'profile_screen.dart';
import 'financial_plan_screen.dart';
import 'budget_buckets_screen.dart';
import 'group_split_screen.dart';
import '../models/date_range_option.dart';
import '../ui/fcl/sleek_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  final bool openManualOnStart;
  const HomeScreen({super.key, this.openManualOnStart = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<OverviewScreenState> _overviewKey =
      GlobalKey<OverviewScreenState>();
  int _index = 0;
  TransactionProvider? _txnProvider;
  VoidCallback? _txnListener;
  bool _categoryPromptRunner = false;

  List<Widget> get _screens => [
        OverviewScreen(
          key: _overviewKey,
          onViewAll: _openTransactionsHistory,
          onOpenPlan: _openFinancialPlan,
          onOpenBudgets: _openBudgetBuckets,
          onOpenGroupSplit: _openGroupSplit,
        ),
        const SectorsScreen(), // Analytics
        const DaywiseScreen(), // Combining logic inside or just using one for now
        const TransactionsScreen(), // Activity
      ];

  final List<SleekNavItem> _navItems = [
    SleekNavItem(icon: HugeIcons.strokeRoundedHome01, label: 'Home'),
    SleekNavItem(icon: HugeIcons.strokeRoundedChartRose, label: 'Charts'),
    SleekNavItem(icon: HugeIcons.strokeRoundedAnalytics01, label: 'Stats'),
    SleekNavItem(icon: HugeIcons.strokeRoundedTaskDaily01, label: 'Activity'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.openManualOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openManualEntry());
    }
    _checkProfileCompletion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _txnProvider = context.read<TransactionProvider>();
      _txnListener = _onTxnProviderChanged;
      _txnProvider!.addListener(_txnListener!);
      _onTxnProviderChanged();
    });
  }

  @override
  void dispose() {
    if (_txnProvider != null && _txnListener != null) {
      _txnProvider!.removeListener(_txnListener!);
    }
    super.dispose();
  }

  void _onTxnProviderChanged() {
    if (!mounted || _categoryPromptRunner) return;
    final p = _txnProvider ?? context.read<TransactionProvider>();
    if (p.state == LoadState.loading) return;
    if (p.transactionsNeedingCategoryReview.isEmpty) return;
    _runCategoryReviewPrompts(p);
  }

  Future<void> _runCategoryReviewPrompts(TransactionProvider p) async {
    if (_categoryPromptRunner || !mounted) return;
    _categoryPromptRunner = true;
    try {
      while (mounted) {
        final list = p.transactionsNeedingCategoryReview;
        if (list.isEmpty) break;
        final t = list.first;
        final picked = await showCategoryReviewSheet(context, t);
        if (!mounted) break;
        if (picked == null) {
          p.skipCategoryReview(t.id);
        } else {
          p.setTransactionCategory(t.id, picked);
        }
      }
    } finally {
      _categoryPromptRunner = false;
    }
  }

  void _checkProfileCompletion() async {
    final onboardingDone = await StorageService.isOnboardingDone();
    final profileDone = await StorageService.isProfileComplete();
    if (onboardingDone && !profileDone && mounted) {
      // Delay slightly so the screen renders first
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: false,
          builder: (_) => ProfilePromptSheet(
            onComplete: () {
              Navigator.pop(context);
              setState(() {}); // Refresh
            },
          ),
        );
      });
    }
  }

  void _showPeriodPicker() async {
    final p = context.read<TransactionProvider>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PeriodSheet(p: p),
    );
  }

  void _openManualEntry() async {
    final draft = await showManualTransactionSheet(context);
    if (draft != null && mounted) {
      context.read<TransactionProvider>().addManualTransaction(
            merchant: draft.merchant,
            amount: draft.amount,
            type: draft.type,
            category: draft.category,
            bank: draft.bank,
            date: draft.date,
          );
    }
  }

  Future<void> _openPdfFlow() async {
    final mode = await showPdfChunkModeSheet(context);
    if (mode == null || !mounted) return;
    context.read<TransactionProvider>().processPdf(mode: mode);
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddOptionsSheet(
        onScanSms: () {
          Navigator.pop(ctx);
          context.read<TransactionProvider>().load();
        },
        onImportPdf: () {
          Navigator.pop(ctx);
          _openPdfFlow();
        },
        onAddManual: () {
          Navigator.pop(ctx);
          _openManualEntry();
        },
      ),
    );
  }

  void _openTransactionsHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _TransactionsHistoryPage()),
    );
  }

  void _openFinancialPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FinancialPlanScreen()),
    );
  }

  void _openBudgetBuckets() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BudgetBucketsScreen()),
    );
  }

  void _openGroupSplit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GroupSplitScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    final topInset = MediaQuery.paddingOf(context).top;
    final appBarBodyHeight = 56.0;
    final appBarTotalHeight = topInset + appBarBodyHeight;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarTotalHeight),
        child: Container(
          color: AppColors.bg,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            topInset + 10,
            AppSpacing.screenHorizontal,
            12,
          ),
          alignment: Alignment.bottomCenter,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Savyit',
                style: GoogleFonts.homemadeApple(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                  letterSpacing: -1,
                  shadows: [
                    Shadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _PeriodChip(p: p, onTap: _showPeriodPicker),
              SizedBox(width: AppSpacing.md),
              _AppBarIconButton(
                icon: HugeIcons.strokeRoundedUser,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen()),
                  ).then((_) {
                    _overviewKey.currentState?.reloadUserAndBuddy();
                  });
                },
              ),
            ],
          ),
        ),
      ),
      body: GridBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.03, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                )),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_index),
            child: _screens[_index],
          ),
        ),
      ),
      floatingActionButton: _AddButton(onTap: _showAddOptions),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SleekDockedBottomNav(
        currentIndex: _index,
        items: _navItems,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TransactionsHistoryPage extends StatelessWidget {
  const _TransactionsHistoryPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Transactions History'),
      ),
      body: GridBackground(
        child: const TransactionsScreen(),
      ),
    );
  }
}

// App Bar Icon Button
class _AppBarIconButton extends StatelessWidget {
  final dynamic icon;
  final VoidCallback onTap;

  const _AppBarIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        splashColor: AppColors.primarySoft.withValues(alpha: 0.45),
        highlightColor: Colors.transparent,
        child: Ink(
          width: AppHitTarget.min,
          height: AppHitTarget.min,
          decoration: AppDecorations.controlSurface(radius: AppRadius.sm),
          child: Center(
            child: HugeIcon(icon: icon, color: AppColors.textMain, size: 19),
          ),
        ),
      ),
    );
  }
}

// Period Selector Chip
class _PeriodChip extends StatelessWidget {
  final TransactionProvider p;
  final VoidCallback onTap;

  const _PeriodChip({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: AppColors.primarySoft.withValues(alpha: 0.55),
        highlightColor: Colors.transparent,
        child: Ink(
          height: AppHitTarget.min,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          decoration: AppDecorations.controlSurface(radius: AppRadius.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration:
                    AppDecorations.iconContainer(color: AppColors.primary),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  size: 13,
                  color: AppColors.iconOnLight,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                p.rangeLabel,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: -0.25,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Floating Add Button with pulse animation
class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: Container(
        width: 64,
        height: 64,
        decoration: AppColors.isMonochrome
            ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(AppColors.primary, Colors.white, 0.14)!,
                    AppColors.primaryDark,
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.42),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : BoxDecoration(
                shape: BoxShape.circle,
                color: AppNeoColors.lime,
                border: Border.all(
                  color: AppNeoColors.strokeBlack,
                  width: 2.5,
                ),
                boxShadow: NeoPopDecorations.hardShadow(
                  5,
                  color: AppNeoColors.shadowInk,
                ),
              ),
        child: FloatingActionButton(
          onPressed: widget.onTap,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          child: Icon(
            Icons.add_rounded,
            color: AppColors.isMonochrome ? Colors.white : AppNeoColors.ink,
            size: 34,
          ),
        ),
      ),
    );
  }
}

// Add Options Bottom Sheet
class _AddOptionsSheet extends StatelessWidget {
  final VoidCallback onScanSms;
  final VoidCallback onImportPdf;
  final VoidCallback onAddManual;

  const _AddOptionsSheet({
    required this.onScanSms,
    required this.onImportPdf,
    required this.onAddManual,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        AppSpacing.xxl,
      ),
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
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.xxl),
            Text(
              'Add Transaction',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Choose how to add your transactions',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: AppSpacing.xxl),

            _AddOptionTile(
              icon: HugeIcons.strokeRoundedMessage01,
              title: 'Scan SMS',
              subtitle: 'Import from bank messages',
              color: AppColors.primary,
              onTap: onScanSms,
            ),
            SizedBox(height: AppSpacing.lg),
            _AddOptionTile(
              icon: HugeIcons.strokeRoundedFileAttachment,
              title: 'Import PDF',
              subtitle: 'Upload bank statements',
              color: AppColors.primary,
              onTap: onImportPdf,
            ),
            SizedBox(height: AppSpacing.lg),
            _AddOptionTile(
              icon: HugeIcons.strokeRoundedPencilEdit01,
              title: 'Add Manually',
              subtitle: 'Enter transaction details',
              color: AppColors.primary,
              onTap: onAddManual,
            ),
            SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _AddOptionTile extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AddOptionTile({
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg + 2,
          ),
          decoration: AppDecorations.controlSurface(radius: AppRadius.lg),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.md + 2),
                decoration: AppDecorations.iconContainer(color: color),
                child: HugeIcon(
                  icon: icon,
                  color: AppColors.isMonochrome ? color : AppColors.iconOnLight,
                  size: 22,
                ),
              ),
              SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
                    SizedBox(height: AppSpacing.xs),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodSheet extends StatelessWidget {
  final TransactionProvider p;
  const _PeriodSheet({required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        AppSpacing.xxl,
      ),
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
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            Text('Select Period',
                style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: AppSpacing.lg),
            ...DateRangeOption.values.map((opt) {
              final isSelected = p.rangeOption == opt;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    p.setRange(opt);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                      horizontal: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (AppColors.isMonochrome
                              ? AppColors.surfaceVariant
                              : AppColors.primarySoft)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: opt.icon,
                          color: isSelected
                              ? (AppColors.isMonochrome
                                  ? AppColors.primary
                                  : AppColors.iconOnLight)
                              : AppColors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt.label,
                            style: GoogleFonts.inter(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? (AppColors.isMonochrome
                                      ? AppColors.primary
                                      : AppColors.textMain)
                                  : AppColors.textMain,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isSelected)
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                            color: AppColors.isMonochrome
                                ? AppColors.primary
                                : AppColors.iconOnLight,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
