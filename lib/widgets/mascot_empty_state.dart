// lib/widgets/mascot_empty_state.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/mascot_dna.dart';
import '../theme/app_theme.dart';
import 'blob_mascot.dart';
import 'neo_pop_button.dart';

class MascotEmptyState extends StatelessWidget {
  final MascotDna dna;
  final String title;
  final String description;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;
  final MascotMood mood;

  const MascotEmptyState({
    super.key,
    required this.dna,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.onCtaTap,
    this.mood = MascotMood.sleeping,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlobMascot(
              dna: dna,
              mood: mood,
              size: 140,
              contrastPlate: true,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onCtaTap != null) ...[
              const SizedBox(height: 24),
              NeoPopButton(
                label: ctaLabel!,
                onTap: onCtaTap,
                fill: AppNeoColors.lime,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
