import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/transaction.dart';
import '../../theme/app_theme.dart';

typedef SleekFormatInr = String Function(double val, {bool showSign});

/// FCL-style list row: tokenized card + gradient ring on category mark (no heavy list-wide motion).
class SleekTransactionTile extends StatelessWidget {
  final Transaction txn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final SleekFormatInr formatAmount;

  const SleekTransactionTile({
    super.key,
    required this.txn,
    required this.onEdit,
    required this.onDelete,
    required this.formatAmount,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.isCredit;
    final dateStr = DateFormat('dd MMM').format(txn.date);
    final categoryColor = AppColors.colorForCategory(txn.category);

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      decoration: AppDecorations.card,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md + 2),
                    gradient: LinearGradient(
                      colors: [
                        categoryColor.withValues(alpha: 0.55),
                        AppNeoColors.lime.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: AppColors.iconForCategory(txn.category),
                          color:
                              AppColors.glyphOnPaleAccent(categoryColor),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn.merchant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Container(
                            margin: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm),
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.textHint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              txn.category,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: categoryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      tooltip: 'Actions',
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      '${isCredit ? '+' : '-'}${formatAmount(txn.amount)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color:
                            isCredit ? AppColors.green : AppColors.textMain,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    ShadBadge.secondary(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2,
                        vertical: 2,
                      ),
                      child: Text(
                        txn.bank,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
