import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/sms_service.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';

class ManualTransactionDraft {
  final String merchant;
  final double amount;
  final String type;
  final String category;
  final String bank;
  final DateTime date;

  const ManualTransactionDraft({
    required this.merchant,
    required this.amount,
    required this.type,
    required this.category,
    required this.bank,
    required this.date,
  });
}

Future<ManualTransactionDraft?> showManualTransactionSheet(
    BuildContext context, {Transaction? initial}) {
  return showModalBottomSheet<ManualTransactionDraft>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ManualTransactionSheet(initial: initial),
  );
}

class ManualTransactionSheet extends StatefulWidget {
  final Transaction? initial;
  const ManualTransactionSheet({super.key, this.initial});

  @override
  State<ManualTransactionSheet> createState() => _ManualTransactionSheetState();
}

class _ManualTransactionSheetState extends State<ManualTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _bankController;

  late String _type;
  late String _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.initial?.merchant ?? '');
    _amountController = TextEditingController(text: widget.initial?.amount.toString() ?? '');
    _bankController = TextEditingController(text: widget.initial?.bank ?? 'Manual');
    
    _type = widget.initial?.type ?? 'debit';
    _category = widget.initial?.category ?? sectors.first.name;
    _date = widget.initial?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDate: _date,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: AppColors.primary,
            onPrimary: AppColors.labelOnSolid(AppColors.primary),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(
          () => _date = DateTime(picked.year, picked.month, picked.day, 12));
    }
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    Navigator.pop(
      context,
      ManualTransactionDraft(
        merchant: _merchantController.text.trim(),
        amount: amount,
        type: _type,
        category: _category,
        bank: _bankController.text.trim(),
        date: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.sheetChrome,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedListView,
                            size: 20,
                            color: AppColors.isMonochrome
                                ? AppColors.primary
                                : AppColors.iconOnLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.initial == null ? 'Manual Transaction' : 'Edit Transaction',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Type'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment<String>(
                        value: 'debit',
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDownLeft01,
                          size: 16,
                          color: AppColors.textMain,
                        ),
                        label: const Text('Outflow'),
                      ),
                      ButtonSegment<String>(
                        value: 'credit',
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowUpRight01,
                          size: 16,
                          color: AppColors.textMain,
                        ),
                        label: const Text('Inflow'),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selected) =>
                        setState(() => _type = selected.first),
                    style: ButtonStyle(
                      side: WidgetStatePropertyAll(
                        BorderSide(
                            color: AppColors.border.withValues(alpha: 0.8),
                            width: 1.4),
                      ),
                      backgroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.primary.withValues(alpha: 0.14);
                        }
                        return AppColors.surface;
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _label('Merchant / Person'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _merchantController,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration('e.g. Zepto, Rent, John'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter a name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _label('Amount (INR)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: _decoration('e.g. 499.00'),
                    validator: (v) {
                      final parsed = double.tryParse((v ?? '').trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _label('Category'),
                  const SizedBox(height: 12),
                  _CategorySelector(
                    selected: _category,
                    onSelected: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 14),
                  _label('Source / Bank'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _bankController,
                    textInputAction: TextInputAction.done,
                    decoration: _decoration('e.g. HDFC, Cash, GPay'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter source';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _label('Date'),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickDate,
                    child: Ink(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 1.4),
                        color: AppColors.surface,
                      ),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar03,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('d MMM yyyy').format(_date),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedTick01,
                        size: 18,
                        color: AppColors.labelOnSolid(AppColors.primary),
                      ),
                      label: Text(
                        widget.initial == null ? 'Save Transaction' : 'Update Transaction',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: AppColors.textMuted,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary, width: 1.8),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final String selected;
  final Function(String) onSelected;

  const _CategorySelector({required this.selected, required this.onSelected});

  Color _getCategoryColor(String name) {
    switch (name) {
      case 'Food & Dining': return const Color(0xFFFF8E3C);
      case 'Transport': return const Color(0xFF0F3460);
      case 'Shopping': return const Color(0xFFFF4D6A);
      case 'Health': return const Color(0xFF00C897);
      case 'Entertainment': return const Color(0xFF6C5CE7);
      case 'Utilities & Bills': return const Color(0xFF5F6C7B);
      case 'Transfer': return const Color(0xFF2A2A2A);
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: sectors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final s = sectors[i];
          final isSelected = s.name == selected;
          final color = _getCategoryColor(s.name);
          return GestureDetector(
            onTap: () => onSelected(s.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? color : AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Text(s.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    s.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? AppColors.labelOnSolid(color)
                          : AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
