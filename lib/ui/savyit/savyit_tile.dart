// lib/ui/savyit/savyit_tile.dart
// Unified tile component — action pills, settings rows, transaction rows, import options.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'savyit_theme.dart';

enum SavyitTileVariant { action, setting, transaction, import_ }

class SavyitTile extends StatefulWidget {
  final SavyitTileVariant variant;

  // Shared
  final VoidCallback? onTap;
  final String? semanticLabel;

  // action
  final Widget? actionIcon;
  final String? actionLabel;

  // setting
  final Widget? settingLeading;
  final String? settingTitle;
  final String? settingSubtitle;
  final Widget? settingTrailing;

  // transaction
  final Widget? txnCategoryIcon;
  final Color? txnCategoryColor;
  final String? txnMerchant;
  final String? txnCategory;
  final String? txnAmount;
  final String? txnDate;
  final bool txnIsDebit;

  // import
  final Widget? importIcon;
  final String? importTitle;
  final String? importSubtitle;

  const SavyitTile.action({
    super.key,
    required Widget icon,
    required String label,
    this.onTap,
    this.semanticLabel,
  })  : variant        = SavyitTileVariant.action,
        actionIcon     = icon,
        actionLabel    = label,
        settingLeading  = null,
        settingTitle    = null,
        settingSubtitle = null,
        settingTrailing = null,
        txnCategoryIcon  = null,
        txnCategoryColor = null,
        txnMerchant      = null,
        txnCategory      = null,
        txnAmount        = null,
        txnDate          = null,
        txnIsDebit       = true,
        importIcon       = null,
        importTitle      = null,
        importSubtitle   = null;

  const SavyitTile.setting({
    super.key,
    required Widget leading,
    required String title,
    this.onTap,
    String? subtitle,
    Widget? trailing,
    this.semanticLabel,
  })  : variant         = SavyitTileVariant.setting,
        settingLeading  = leading,
        settingTitle    = title,
        settingSubtitle = subtitle,
        settingTrailing = trailing,
        actionIcon      = null,
        actionLabel     = null,
        txnCategoryIcon  = null,
        txnCategoryColor = null,
        txnMerchant      = null,
        txnCategory      = null,
        txnAmount        = null,
        txnDate          = null,
        txnIsDebit       = true,
        importIcon       = null,
        importTitle      = null,
        importSubtitle   = null;

  const SavyitTile.transaction({
    super.key,
    required Widget categoryIcon,
    required Color categoryColor,
    required String merchant,
    required String category,
    required String amount,
    required String date,
    bool isDebit = true,
    this.onTap,
    this.semanticLabel,
  })  : variant         = SavyitTileVariant.transaction,
        txnCategoryIcon  = categoryIcon,
        txnCategoryColor = categoryColor,
        txnMerchant      = merchant,
        txnCategory      = category,
        txnAmount        = amount,
        txnDate          = date,
        txnIsDebit       = isDebit,
        actionIcon       = null,
        actionLabel      = null,
        settingLeading   = null,
        settingTitle     = null,
        settingSubtitle  = null,
        settingTrailing  = null,
        importIcon       = null,
        importTitle      = null,
        importSubtitle   = null;

  const SavyitTile.import_({
    super.key,
    required Widget icon,
    required String title,
    String? subtitle,
    this.onTap,
    this.semanticLabel,
  })  : variant         = SavyitTileVariant.import_,
        importIcon      = icon,
        importTitle     = title,
        importSubtitle  = subtitle,
        actionIcon      = null,
        actionLabel     = null,
        settingLeading  = null,
        settingTitle    = null,
        settingSubtitle = null,
        settingTrailing = null,
        txnCategoryIcon  = null,
        txnCategoryColor = null,
        txnMerchant      = null,
        txnCategory      = null,
        txnAmount        = null,
        txnDate          = null,
        txnIsDebit       = true;

  @override
  State<SavyitTile> createState() => _SavyitTileState();
}

class _SavyitTileState extends State<SavyitTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = SavyitTheme.of(context);
    final c = t.colors;

    Widget child;
    switch (widget.variant) {
      case SavyitTileVariant.action:
        child = _buildAction(c);
        break;
      case SavyitTileVariant.setting:
        child = _buildSetting(c);
        break;
      case SavyitTileVariant.transaction:
        child = _buildTransaction(c);
        break;
      case SavyitTileVariant.import_:
        child = _buildImport(c);
        break;
    }

    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      child: GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) {
          HapticFeedback.lightImpact();
          setState(() => _pressed = true);
        },
        onTapUp: widget.onTap == null ? null : (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => _pressed = false),
        child: AnimatedOpacity(
          opacity: _pressed ? 0.65 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: child,
        ),
      ),
    );
  }

  Widget _buildAction(SavyitColorTokens c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.actionIcon != null) ...[
            widget.actionIcon!,
            const SizedBox(width: 8),
          ],
          Text(
            widget.actionLabel ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textMain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetting(SavyitColorTokens c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          widget.settingLeading ?? const SizedBox.shrink(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.settingTitle ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textMain,
                  ),
                ),
                if (widget.settingSubtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.settingSubtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.settingTrailing != null) widget.settingTrailing!,
        ],
      ),
    );
  }

  Widget _buildTransaction(SavyitColorTokens c) {
    final accent = widget.txnCategoryColor ?? c.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: widget.txnCategoryIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.txnMerchant ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.txnCategory ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.txnAmount ?? '',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.txnIsDebit ? c.textMain : c.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.txnDate ?? '',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: c.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImport(SavyitColorTokens c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: widget.importIcon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.importTitle ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textMain,
                  ),
                ),
                if (widget.importSubtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.importSubtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: c.textMuted),
        ],
      ),
    );
  }
}
