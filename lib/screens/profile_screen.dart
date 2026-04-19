// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/transaction_provider.dart';
import '../services/auth_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_background.dart';
import '../widgets/blob_mascot.dart';
import '../models/mascot_dna.dart';
import '../ui/savyit/index.dart';
import 'financial_plan_screen.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    final userName = p.userName;
    final avatarColor = AppColors.primaryLight;
    final avatarTextColor = avatarColor.computeLuminance() < 0.45
        ? Colors.white
        : AppColors.textMain;

    return GridBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Settings'),
          centerTitle: true,
          leading: IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: AppColors.textMain,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              SizedBox(height: AppSpacing.sm),

              // Profile first — avoids a large neo "shell" above the fold that
              // looked empty when the buddy editor (below) failed to read as content.
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppSpacing.xxl),
                decoration: AppDecorations.cardElevated,
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: avatarColor,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.md,
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: avatarTextColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg),
                    Text(
                      userName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'Free Plan',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppNeoColors.shadowInk,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.xxl),

              // Buddy customization — labeled so it never reads as a blank card.
              Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.md),
                child: Text(
                  'MONEY BUDDY',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const _BuddySectionCard(),

              SizedBox(height: AppSpacing.xxl),

              // Preferences Section
              _SettingsSection(
                title: 'Preferences',
                children: [
                  _SettingsTile(
                    icon: HugeIcons.strokeRoundedUser,
                    title: 'Edit Profile',
                    subtitle: 'Change your name',
                    onTap: () => _showEditNameDialog(context, p),
                  ),
                  _SettingsTile(
                    icon: HugeIcons.strokeRoundedCoins01,
                    title: 'Currency',
                    subtitle: 'Display currency',
                    trailing: Text(
                      p.selectedCurrency,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentTextOnSurface,
                      ),
                    ),
                    onTap: () => _showCurrencyDialog(context, p),
                  ),
                  _SettingsTile(
                    icon: HugeIcons.strokeRoundedPaintBoard,
                    title: 'Monochrome Mode',
                    subtitle: 'Clean & minimalist look',
                    trailing: Switch.adaptive(
                      value: p.isMonochrome,
                      onChanged: (_) => p.toggleTheme(),
                    ),
                    onTap: () => p.toggleTheme(),
                  ),
                  _SettingsTile(
                    icon: HugeIcons.strokeRoundedChart,
                    title: 'My Financial Plan',
                    subtitle: 'Your personalized guide',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FinancialPlanScreen())),
                  ),
                  if (!kIsWeb && AuthService.isLoggedIn)
                    _SettingsTile(
                      icon: HugeIcons.strokeRoundedLogout01,
                      title: 'Log out',
                      subtitle: 'Sign out of your account',
                      iconColor: AppColors.textSecondary,
                      onTap: () => _showLogoutDialog(context),
                    ),
                ],
              ),

              SizedBox(height: AppSpacing.xl),

              // Data Section
              _SettingsSection(
                title: 'Data',
                children: [
                  const _SmsScanSettingsBlock(),
                  _SettingsTile(
                    icon: HugeIcons.strokeRoundedFileExport,
                    title: 'Export Data',
                    subtitle: 'Download your transactions',
                    onTap: () => _showExportOptions(context, p),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.xl),

              // Danger Zone
              _SettingsSection(
                title: 'Danger Zone',
                children: [
                  _SettingsTile(
                    icon: HugeIcons.strokeRoundedDelete02,
                    title: 'Reset All Data',
                    subtitle: 'Delete all transactions',
                    iconColor: AppColors.red,
                    titleColor: AppColors.red,
                    onTap: () => _showResetDialog(context),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.xxxl),

              // App Info — versionName + versionCode from pubspec / Gradle (verify release installs).
              const _AppVersionFooter(),

              SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'Log out?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'You will need to sign in again to use cloud AI for SMS. Your saved transactions stay on this device.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.signOut();
              await StorageService.setAuthSkipped(false);
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) =>
                      const OnboardingScreen(reauthAfterLogout: true),
                ),
                (route) => false,
              );
            },
            child: Text(
              'Log out',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, TransactionProvider p) {
    final controller = TextEditingController(text: p.userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'Edit Profile',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Your name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              if (newName == p.userName) {
                if (ctx.mounted) Navigator.pop(ctx);
                return;
              }
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c2) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  title: Text(
                    'Update your name?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  content: Text(
                    'This updates how you appear across the app (home, exports, and reports).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c2, false),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c2, true),
                      child: Text(
                        'Update',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentTextOnSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                p.updateProfile(name: newName);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.accentTextOnSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context, TransactionProvider p) {
    final currencies = ['₹', '\$', '€', '£', '¥'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'Select Currency',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: currencies.map((c) {
            return ListTile(
              title: Text(
                c,
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              trailing: p.selectedCurrency == c
                  ? Icon(
                      Icons.check,
                      color: AppColors.isMonochrome
                          ? AppColors.primary
                          : AppColors.iconOnLight,
                    )
                  : null,
              onTap: () async {
                if (c == p.selectedCurrency) {
                  Navigator.pop(ctx);
                  return;
                }
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (c2) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    title: Text(
                      'Change display currency?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    content: Text(
                      'All amounts will show as $c. Stored transaction numbers do not convert — only the symbol changes.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c2, false),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c2, true),
                        child: Text(
                          'Use $c',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentTextOnSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  p.updateProfile(currency: c);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showExportOptions(BuildContext context, TransactionProvider p) {
    if (p.transactions.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              Text(
                'Export Format',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: AppSpacing.lg),
              ListTile(
                leading: HugeIcon(
                  icon: HugeIcons.strokeRoundedCsv01,
                  color: AppColors.isMonochrome
                      ? AppColors.primary
                      : AppColors.iconOnLight,
                  size: 28,
                ),
                title: Text('CSV File (Excel/Sheets)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportData(context, p);
                },
              ),
              ListTile(
                leading: HugeIcon(
                    icon: HugeIcons.strokeRoundedPdf01,
                    color: AppColors.accent,
                    size: 28),
                title: Text('PDF Document',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportPdfData(context, p);
                },
              ),
              SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdfData(
      BuildContext context, TransactionProvider p) async {
    try {
      final pdf = pw.Document();
      final transactions = p.transactions;

      // Neo-brutalist Savyit tokens (match app_theme AppNeoColors / pastel shell)
      final pdfInk = PdfColor.fromHex('#0A0A0F');
      final pdfStroke = PdfColor.fromHex('#0D0D0D');
      final pdfShadow = PdfColor.fromHex('#1B3D2F');
      final pdfLime = PdfColor.fromHex('#D1FF4E');
      final pdfPink = PdfColor.fromHex('#FF4D8F');
      final pdfLavender = PdfColor.fromHex('#EDE7FF');
      final pdfWhite = PdfColors.white;
      final pdfMuted = PdfColor.fromHex('#595155');
      final pdfGreen = PdfColor.fromHex('#1B5E20');

      final fontRegular = await PdfGoogleFonts.interRegular();
      final fontBold = await PdfGoogleFonts.interBold();
      final fontBlack = await PdfGoogleFonts.interBold();
      final fontLogo = await PdfGoogleFonts.outfitBlack();

      String fmtAmt(double v) =>
          v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
      final sym = p.selectedCurrency;

      double totalInflow = 0;
      double totalOutflow = 0;
      for (final t in transactions) {
        if (t.isDebit) {
          totalOutflow += t.amount;
        } else {
          totalInflow += t.amount;
        }
      }
      final net = totalInflow - totalOutflow;

      /// Hard-shadow card: forest block peeking bottom-right, white face + thick stroke.
      pw.Widget neoCard({
        required PdfColor fill,
        required pw.Widget child,
        double radius = 14,
        double pad = 14,
        double shadowShift = 5,
      }) {
        return pw.Container(
          margin: pw.EdgeInsets.only(
            bottom: shadowShift,
            right: shadowShift,
          ),
          child: pw.Stack(
            children: [
              pw.Positioned(
                left: shadowShift,
                top: shadowShift,
                right: 0,
                bottom: 0,
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    color: pdfShadow,
                    borderRadius:
                        pw.BorderRadius.all(pw.Radius.circular(radius)),
                  ),
                ),
              ),
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: fill,
                  borderRadius:
                      pw.BorderRadius.all(pw.Radius.circular(radius)),
                  border: pw.Border.all(color: pdfStroke, width: 2.5),
                ),
                padding: pw.EdgeInsets.all(pad),
                child: child,
              ),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: pw.EdgeInsets.zero,
            buildBackground: (ctx) => pw.Container(color: pdfLavender),
          ),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
          footer: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 20),
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: pw.BoxDecoration(
                color: pdfLime,
                border: pw.Border.all(color: pdfStroke, width: 2),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'SAVYIT · NEO MONEY EXPORT',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8,
                      color: pdfInk,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.Text(
                    'PAGE ${context.pageNumber} / ${context.pagesCount}',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8,
                      color: pdfInk,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              // Top tape
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 10, horizontal: 14),
                margin: const pw.EdgeInsets.only(bottom: 18),
                decoration: pw.BoxDecoration(
                  color: pdfLime,
                  border: pw.Border.all(color: pdfStroke, width: 2.5),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '▌SAVYIT',
                      style: pw.TextStyle(
                        font: fontLogo,
                        fontSize: 18,
                        color: pdfInk,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: pdfPink,
                        border: pw.Border.all(color: pdfStroke, width: 2),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'STAMP',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 7,
                              color: pdfInk,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.Text(
                            DateTime.now().toIso8601String().split('T')[0],
                            style: pw.TextStyle(
                              font: fontBlack,
                              fontSize: 11,
                              color: pdfInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              neoCard(
                fill: pdfWhite,
                pad: 18,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TRANSACTION DUMP',
                            style: pw.TextStyle(
                              font: fontBlack,
                              fontSize: 11,
                              color: pdfInk,
                              letterSpacing: 1.2,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Financial snapshot · high-contrast export',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 9,
                              color: pdfMuted,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            '${transactions.length} rows · $sym in use',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 8,
                              color: pdfMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // KPI row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: neoCard(
                      fill: pdfLime,
                      pad: 12,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'INFLOW',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 8,
                              color: pdfInk,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            '$sym${fmtAmt(totalInflow)}',
                            style: pw.TextStyle(
                              font: fontBlack,
                              fontSize: 20,
                              color: pdfInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: neoCard(
                      fill: pdfPink,
                      pad: 12,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'OUTFLOW',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 8,
                              color: pdfInk,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            '$sym${fmtAmt(totalOutflow)}',
                            style: pw.TextStyle(
                              font: fontBlack,
                              fontSize: 20,
                              color: pdfInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: neoCard(
                      fill: pdfWhite,
                      pad: 12,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'NET',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 8,
                              color: pdfMuted,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            '$sym${fmtAmt(net)}',
                            style: pw.TextStyle(
                              font: fontBlack,
                              fontSize: 20,
                              color: net >= 0 ? pdfGreen : pdfPink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: pdfLime,
                  border: pw.Border.all(color: pdfStroke, width: 2.5),
                  borderRadius:
                      const pw.BorderRadius.vertical(top: pw.Radius.circular(12)),
                ),
                child: pw.Text(
                  'LEDGER (ALL CAPS ENERGY)',
                  style: pw.TextStyle(
                    font: fontBlack,
                    fontSize: 10,
                    color: pdfInk,
                    letterSpacing: 1.4,
                  ),
                ),
              ),

              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdfStroke, width: 2.5),
                  borderRadius: const pw.BorderRadius.vertical(
                    bottom: pw.Radius.circular(12),
                  ),
                ),
                child: pw.TableHelper.fromTextArray(
                  border: null,
                  cellPadding:
                      const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  rowDecoration:
                      const pw.BoxDecoration(color: PdfColors.white),
                  oddRowDecoration:
                      pw.BoxDecoration(color: PdfColor.fromHex('#F3EEFF')),
                  headerStyle: pw.TextStyle(
                    color: pdfInk,
                    font: fontBlack,
                    fontSize: 8,
                    letterSpacing: 0.6,
                  ),
                  headerDecoration: pw.BoxDecoration(color: pdfLime),
                  cellHeight: 32,
                  cellStyle: pw.TextStyle(
                    color: pdfInk,
                    font: fontRegular,
                    fontSize: 8,
                  ),
                  headers: [
                    'DATE',
                    'MERCHANT',
                    'CAT',
                    'BANK',
                    'TYPE',
                    'AMT',
                  ],
                  data: transactions.map((t) {
                    return [
                      t.date.toIso8601String().split('T')[0],
                      t.merchant.toUpperCase(),
                      t.category.toUpperCase(),
                      t.bank.toUpperCase(),
                      t.isDebit ? 'OUT' : 'IN',
                      '$sym${fmtAmt(t.amount)}',
                    ];
                  }).toList(),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.center,
                    5: pw.Alignment.centerRight,
                  },
                ),
              ),
            ];
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/savyit_transactions_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await ShareService.shareFile(
        file: file,
        mimeType: 'application/pdf',
        subject: SavyitShareCopy.exportPdfSubject(),
        text: SavyitShareCopy.exportPdfCaption(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF ready — pick an app to save or share'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Export failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    }
  }

  Future<void> _exportData(BuildContext context, TransactionProvider p) async {
    try {
      if (p.transactions.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions to export')),
        );
        return;
      }

      // Generate CSV content
      final buffer = StringBuffer();
      // CSV Header
      buffer.writeln(
          'ID,Date,Merchant,Amount,Category,Bank/Source,Type(Debit/Credit)');

      for (final t in p.transactions) {
        // Escape standard CSV fields
        final sfId = '"${t.id}"';
        final sfDate = '"${t.date.toIso8601String()}"';
        final sfMerchant = '"${t.merchant.replaceAll('"', '""')}"';
        final sfAmount = '${t.amount}';
        final sfCategory = '"${t.category}"';
        final sfBank = '"${t.bank}"';
        final sfType = '"${t.isDebit ? 'Debit' : 'Credit'}"';

        buffer.writeln(
            '$sfId,$sfDate,$sfMerchant,$sfAmount,$sfCategory,$sfBank,$sfType');
      }

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/savyit_transactions_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      // Share it
      await ShareService.shareFile(
        file: file,
        mimeType: 'text/csv',
        subject: SavyitShareCopy.exportCsvSubject(),
        text: SavyitShareCopy.exportCsvCaption(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV ready — pick an app to save or share'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Export failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export data: $e')),
      );
    }
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'Reset All Data?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'This will permanently delete all your transactions and settings. This action cannot be undone.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Buddy Section Card ──────────────────────────────────────────────────────

class _BuddySectionCard extends StatefulWidget {
  const _BuddySectionCard();

  @override
  State<_BuddySectionCard> createState() => _BuddySectionCardState();
}

class _BuddySectionCardState extends State<_BuddySectionCard> {
  MascotDna _dna = MascotDna.defaults();
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _dna.name);
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dna = await StorageService.loadMascotDna();
    if (mounted) {
      setState(() { _dna = dna; _nameCtrl.text = dna.name; });
    }
  }

  Future<void> _save() async {
    final updated = _dna.copyWith(name: _nameCtrl.text.trim().isEmpty ? 'Blobby' : _nameCtrl.text.trim());
    await StorageService.saveMascotDna(updated);
    if (mounted) {
      setState(() => _dna = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buddy saved!'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppNeoColors.shadowInk;
    return SavyitCard(
      variant: SavyitCardVariant.pop,
      padding: const EdgeInsets.all(20),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: AppColors.textMain),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppNeoColors.lime,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Customize your money buddy',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          height: 1.2,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BlobMascot(
                  dna: _dna,
                  mood: MascotMood.curious,
                  size: 88,
                  contrastPlate: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    cursorColor: AppNeoColors.lime,
                    decoration: InputDecoration(
                      hintText: 'Buddy name',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      hintStyle: GoogleFonts.inter(
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                    onChanged: (v) => setState(() => _dna = _dna.copyWith(name: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'COLOUR',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: blobColorMap.entries.map((e) {
                final selected = _dna.color == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _dna = _dna.copyWith(color: e.key)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? ink : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: selected
                          ? NeoPopDecorations.hardShadow(2, color: ink)
                          : null,
                    ),
                    child: selected
                        ? Icon(Icons.check, size: 16, color: ink)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'ACCESSORY',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: blobAccessoryOptions.map((opt) {
                final acc = opt['id']!;
                final emoji = opt['emoji']!;
                final selected = _dna.accessory == acc;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _dna = _dna.copyWith(accessory: acc)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primarySoft
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? ink : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save buddy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppVersionFooter extends StatelessWidget {
  const _AppVersionFooter();

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        if (snap.hasError || !snap.hasData) {
          return Text('Savyit', style: textStyle);
        }
        final p = snap.data!;
        return Text(
          'Savyit v${p.version} (${p.buildNumber})',
          style: textStyle,
        );
      },
    );
  }
}

class _SmsScanSettingsBlock extends StatefulWidget {
  const _SmsScanSettingsBlock();

  @override
  State<_SmsScanSettingsBlock> createState() => _SmsScanSettingsBlockState();
}

class _SmsScanSettingsBlockState extends State<_SmsScanSettingsBlock> {
  bool _incremental = true;
  String? _cursorYmd;

  @override
  void initState() {
    super.initState();
    _reloadPrefs();
  }

  Future<void> _reloadPrefs() async {
    final inc = await StorageService.getIncrementalSmsScanEnabled();
    final c = await StorageService.getSmsScanCursorEndInclusive();
    if (!mounted) return;
    setState(() {
      _incremental = inc;
      if (c == null) {
        _cursorYmd = null;
      } else {
        _cursorYmd =
            '${c.year}-${c.month.toString().padLeft(2, '0')}-${c.day.toString().padLeft(2, '0')}';
      }
    });
  }

  Future<void> _confirmClearCursor(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'Reset SMS scan position?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'The next SMS scan will read your full selected date range again, then resume incremental updates.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Reset',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.accentTextOnSurface,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await StorageService.clearSmsScanCursor();
    await _reloadPrefs();
  }

  Future<void> _confirmFullRescan(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'Rescan full date range?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'This one run re-reads all SMS in your current date-range setting, then updates the saved scan position.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Rescan',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.accentTextOnSurface,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<TransactionProvider>().loadFullSmsWindowRescan();
    if (context.mounted) await _reloadPrefs();
  }

  @override
  Widget build(BuildContext context) {
    final cursorSubtitle = _cursorYmd == null
        ? 'No saved day yet — next scan uses your full date range'
        : 'Last successful scan through $_cursorYmd (inclusive)';
    Widget div() => Divider(
          height: 1,
          indent: AppSpacing.xl + 40,
          endIndent: AppSpacing.lg,
          color: AppColors.border,
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsTile(
          icon: HugeIcons.strokeRoundedMessage02,
          title: 'Incremental SMS scan',
          subtitle:
              'Skip days already scanned; only read newer days (within your range).',
          trailing: Switch.adaptive(
            value: _incremental,
            onChanged: (v) async {
              await StorageService.setIncrementalSmsScanEnabled(v);
              if (mounted) setState(() => _incremental = v);
            },
          ),
          onTap: () async {
            final v = !_incremental;
            await StorageService.setIncrementalSmsScanEnabled(v);
            if (mounted) setState(() => _incremental = v);
          },
        ),
        div(),
        _SettingsTile(
          icon: HugeIcons.strokeRoundedCalendar03,
          title: 'Reset SMS scan position',
          subtitle: cursorSubtitle,
          onTap: () => _confirmClearCursor(context),
        ),
        div(),
        _SettingsTile(
          icon: HugeIcons.strokeRoundedRefresh,
          title: 'Rescan full date range',
          subtitle: 'One full pass; ignores saved position',
          onTap: () => _confirmFullRescan(context),
        ),
      ],
    );
  }
}

// ── Settings Section ─────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.md),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        SavyitCard(
          variant: SavyitCardVariant.standard,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: children.asMap().entries.map((entry) {
                final isLast = entry.key == children.length - 1;
                return Column(
                  children: [
                    entry.value,
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: AppSpacing.xl + 40,
                        endIndent: AppSpacing.lg,
                        color: AppColors.border,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    color: iconColor ??
                        (AppColors.isMonochrome
                            ? AppColors.primary
                            : AppColors.iconOnLight),
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? AppColors.textMain,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: AppColors.textHint,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
