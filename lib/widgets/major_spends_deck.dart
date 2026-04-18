// lib/widgets/major_spends_deck.dart
// Top spends: fixed viewport + vertical PageView — swipe moves cards, not the home screen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../theme/app_theme.dart';

typedef FormatInr = String Function(double val, {bool showSign});

/// Swipe **up / down** inside the deck to browse up to 5 largest debits.
/// The deck has a bounded height so the overview scroll view stays stable.
class MajorSpendsDeck extends StatefulWidget {
  final List<Transaction> spends;
  final String periodLabel;
  final FormatInr formatInr;

  const MajorSpendsDeck({
    super.key,
    required this.spends,
    required this.periodLabel,
    required this.formatInr,
  });

  @override
  State<MajorSpendsDeck> createState() => _MajorSpendsDeckState();
}

class _MajorSpendsDeckState extends State<MajorSpendsDeck> {
  late final PageController _pageController;
  int _page = 0;

  static const _pageHeight = 232.0;
  static const _indicatorGap = 10.0;

  String _sig(List<Transaction> l) => l.map((e) => e.id).join(',');

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(MajorSpendsDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sig(oldWidget.spends) != _sig(widget.spends)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pageController.jumpToPage(0);
          setState(() => _page = 0);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.spends.isEmpty) return const SizedBox.shrink();

    final title =
        widget.spends.length == 1 ? 'Major spend' : 'Major spends';
    final n = widget.spends.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Largest outflows · ${widget.periodLabel}',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          n > 1 ? 'Swipe up or down · top $n' : 'Top outflow this period',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _pageHeight,
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: n,
            onPageChanged: (i) => setState(() => _page = i),
            physics: const BouncingScrollPhysics(),
            allowImplicitScrolling: false,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: _MajorSpendPageCard(
                  txn: widget.spends[index],
                  rank: index + 1,
                  formatInr: widget.formatInr,
                ),
              );
            },
          ),
        ),
        SizedBox(height: _indicatorGap),
        _PageDots(count: n, index: _page),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int index;

  const _PageDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: on
                ? (AppColors.isMonochrome
                    ? AppColors.primary
                    : AppNeoColors.lime)
                : AppColors.textMuted.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
            border: AppColors.isMonochrome
                ? null
                : Border.all(
                    color: AppNeoColors.strokeBlack.withValues(alpha: 0.35),
                    width: 1,
                  ),
          ),
        );
      }),
    );
  }
}

class _MajorSpendPageCard extends StatelessWidget {
  final Transaction txn;
  final int rank;
  final FormatInr formatInr;

  const _MajorSpendPageCard({
    required this.txn,
    required this.rank,
    required this.formatInr,
  });

  @override
  Widget build(BuildContext context) {
    final cat = txn.category;
    final catColor = AppColors.colorForCategory(cat);
    final dateStr = DateFormat('EEE, d MMM').format(txn.date);
    final isTop = rank == 1;

    final decoration = AppColors.isMonochrome
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface,
                Color.lerp(AppColors.surface, AppColors.surface2, 0.4)!,
              ],
            ),
            border: Border.all(
              color: isTop
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
              width: isTop ? 1.5 : 1.1,
            ),
            boxShadow: AppShadows.md,
          )
        : NeoPopDecorations.card(
            fill: AppColors.surface,
            radius: AppRadius.xl,
            shadowOffset: isTop ? 6 : 5,
          );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: decoration,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isTop
                          ? (AppColors.isMonochrome
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppNeoColors.lime.withValues(alpha: 0.4))
                          : AppColors.surface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.isMonochrome
                            ? AppColors.border
                            : AppNeoColors.strokeBlack,
                        width: AppColors.isMonochrome ? 1 : 1.5,
                      ),
                    ),
                    child: Text(
                      '#$rank of top spends',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.isMonochrome
                            ? AppColors.border.withValues(alpha: 0.7)
                            : AppNeoColors.strokeBlack,
                        width: AppColors.isMonochrome ? 1 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: AppColors.iconForCategory(cat),
                        color: AppColors.glyphOnPaleAccent(catColor),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          txn.merchant,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Outflow',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatInr(txn.amount),
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textMain,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
