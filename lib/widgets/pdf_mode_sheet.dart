import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';

Future<PdfChunkMode?> showPdfChunkModeSheet(BuildContext context) {
  return showModalBottomSheet<PdfChunkMode>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PdfChunkModeSheet(),
  );
}

class _PdfChunkModeSheet extends StatelessWidget {
  const _PdfChunkModeSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sheetChrome,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedPdf01,
                      size: 20,
                      color: AppColors.isMonochrome
                          ? AppColors.primary
                          : AppColors.iconOnLight,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PDF Analysis Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Choose which part of the statement to send to AI.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ModeTile(
              mode: PdfChunkMode.firstHalf,
              title: 'First half only',
              subtitle: 'Analyze the first section of the statement.',
              icon: HugeIcons.strokeRoundedArrowUpRight01,
            ),
            const SizedBox(height: 10),
            _ModeTile(
              mode: PdfChunkMode.secondHalf,
              title: 'Second half only',
              subtitle: 'Analyze the second section of the statement.',
              icon: HugeIcons.strokeRoundedArrowDownLeft01,
            ),
            const SizedBox(height: 10),
            _ModeTile(
              mode: PdfChunkMode.bothHalves,
              title: 'Both halves (combined)',
              subtitle: 'Recommended for monthly statements.',
              icon: HugeIcons.strokeRoundedLink04,
              highlighted: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final PdfChunkMode mode;
  final String title;
  final String subtitle;
  final dynamic icon;
  final bool highlighted;

  const _ModeTile({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.pop(context, mode),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: highlighted
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  size: 20,
                  color: highlighted
                      ? (AppColors.isMonochrome
                          ? AppColors.primary
                          : AppColors.iconOnLight)
                      : AppColors.textMain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
