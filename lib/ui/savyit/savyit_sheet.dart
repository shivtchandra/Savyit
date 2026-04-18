// lib/ui/savyit/savyit_sheet.dart
// Standardised modal bottom sheet with consistent handle, header, and padding.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'savyit_theme.dart';

class SavyitSheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;

  const SavyitSheetHeader({
    super.key,
    required this.title,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = SavyitTheme.of(context).colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.textMain,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (onClose != null)
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: c.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

/// Consistent drag handle displayed at the top of every sheet.
class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final c = SavyitTheme.of(context).colors;
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: c.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Show a standardised bottom sheet.
///
/// [builder] receives a scroll controller you can pass to any inner list.
Future<T?> showSavyitSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext, ScrollController) builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: Container(
          decoration: BoxDecoration(
            color: AppColors.sheetChrome,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: SavyitTheme.of(ctx).colors.border,
              width: 1,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const _SheetHandle(),
                const SizedBox(height: 8),
                DraggableScrollableSheet(
                  initialChildSize: 1,
                  maxChildSize: 1,
                  minChildSize: 0.5,
                  expand: false,
                  builder: (_, scrollCtrl) => builder(ctx, scrollCtrl),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
