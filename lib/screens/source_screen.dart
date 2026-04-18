// lib/screens/source_screen.dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pdf_mode_sheet.dart';
import 'home_screen.dart';

class SourceScreen extends StatelessWidget {
  const SourceScreen({super.key});

  Future<void> _openPdfFlow(BuildContext context) async {
    final mode = await showPdfChunkModeSheet(context);
    if (mode == null || !context.mounted) return;

    final p = context.read<TransactionProvider>();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
    await p.processPdf(mode: mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Decorative background elements
          Positioned(
            top: -100, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.primary.withValues(alpha: 0.15), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: -50, right: -50,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.primary.withValues(alpha: 0.1), Colors.transparent]),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // App Logo/Branding
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.textMain,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: AppColors.textMain.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 15)),
                    ],
                  ),
                  child: const HugeIcon(icon: HugeIcons.strokeRoundedMoney03, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 32),
                
                Text('Savyit', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 12),
                Text(
                  'Your personal finance intelligence. Classify bank SMS and statements automatically with privacy-first AI.',
                  style: TextStyle(fontSize: 16, color: AppColors.textMuted, height: 1.6, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 48),
                
                Text('START TRACKING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: 2)),
                const SizedBox(height: 20),
                
                _SourceTile(
                  icon: HugeIcons.strokeRoundedMessage02,
                  title: 'SMS Intelligent Scan',
                  subtitle: 'Directly analyze bank messages on this device.',
                  highlight: 'RECOMMENDED',
                  onTap: () async {
                    final p = context.read<TransactionProvider>();
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
                    await p.load();
                  },
                ),
                const SizedBox(height: 16),
                _SourceTile(
                  icon: HugeIcons.strokeRoundedPdf01,
                  title: 'PDF Bank Statements',
                  subtitle: 'Upload and parse any bank PDF statement.',
                  highlight: 'AI POWERED',
                  onTap: () => _openPdfFlow(context),
                ),
                const SizedBox(height: 16),
                _SourceTile(
                  icon: HugeIcons.strokeRoundedListView,
                  title: 'Manual Accounting',
                  subtitle: 'Input transactions manually into your ledger.',
                  highlight: 'OFFLINE',
                  onTap: () {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen(openManualOnStart: true)));
                  },
                ),
                
                const SizedBox(height: 60),
                Center(
                  child: Opacity(
                    opacity: 0.6,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedShield01, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text('End-to-end local processing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final String highlight;
  final VoidCallback onTap;

  const _SourceTile({required this.icon, required this.title, required this.subtitle, required this.highlight, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.textMain.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: HugeIcon(
                icon: icon,
                size: 26,
                color: AppColors.isMonochrome ? AppColors.primary : AppColors.iconOnLight,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textMain), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      highlight,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: AppColors.isMonochrome
                            ? AppColors.primary
                            : AppColors.primaryDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500, height: 1.4)),
              ]),
            ),
            const SizedBox(width: 12),
            HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 20, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }
}
