import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/sms_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet: user picks a spending category when auto-detect used "Other".
Future<String?> showCategoryReviewSheet(
  BuildContext context,
  Transaction transaction,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CategoryReviewBody(transaction: transaction),
  );
}

class _CategoryReviewBody extends StatefulWidget {
  final Transaction transaction;
  const _CategoryReviewBody({required this.transaction});

  @override
  State<_CategoryReviewBody> createState() => _CategoryReviewBodyState();
}

class _CategoryReviewBodyState extends State<_CategoryReviewBody> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.transaction.category == 'Other'
        ? sectors.first.name
        : widget.transaction.category;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final names =
        sectors.map((s) => s.name).where((n) => n.isNotEmpty).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.sheetChrome,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick a category',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We could not auto-match a sector for this transaction.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.merchant,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${t.type == 'credit' ? '+' : '-'}${NumberFormat.compact().format(t.amount)} · ${DateFormat('d MMM').format(t.date)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Category',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: names.map((name) {
                  final sel = _selected == name;
                  return ChoiceChip(
                    label: Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: sel
                            ? AppColors.labelOnSolid(AppColors.primary)
                            : AppColors.textMain,
                      ),
                    ),
                    selected: sel,
                    onSelected: (_) => setState(() => _selected = name),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.bg,
                    side: BorderSide(
                      color: sel ? AppColors.primary : AppColors.border,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop<String?>(context),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.labelOnSolid(AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
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
