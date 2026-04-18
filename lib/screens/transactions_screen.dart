// lib/screens/transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../widgets/manual_transaction_sheet.dart';
import '../widgets/pdf_mode_sheet.dart';
import '../ui/fcl/sleek_transaction_tile.dart';
import '../ui/savyit/index.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TransactionProvider>();
    if (_searchController.text != provider.searchQuery) {
      _searchController.value = TextEditingValue(
        text: provider.searchQuery,
        selection: TextSelection.collapsed(offset: provider.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    final visibleTxns = p.activityVisible;

    return Column(
      children: [
        // Search & Filter Header
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
            AppSpacing.screenHorizontal,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Field
              TextField(
                controller: _searchController,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain,
                ),
                onChanged: p.setSearch,
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 40),
                ),
              ),
              SizedBox(height: AppSpacing.lg),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: p.filterType.isEmpty,
                      onTap: () => p.setType(''),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _FilterChip(
                      label: 'Income',
                      isSelected: p.filterType == 'credit',
                      color: AppColors.green,
                      onTap: () => p.setType('credit'),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _FilterChip(
                      label: 'Expense',
                      isSelected: p.filterType == 'debit',
                      color: AppColors.red,
                      onTap: () => p.setType('debit'),
                    ),
                    SizedBox(width: AppSpacing.md),
                    _DropdownChip(
                      hint: 'Category',
                      value: p.filterSector,
                      items: p.availableSectors,
                      onChanged: p.setSector,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _DropdownChip(
                      hint: 'Bank',
                      value: p.filterBank,
                      items: p.availableBanks,
                      onChanged: p.setBank,
                    ),
                  ],
                ),
              ),
              
              // NEW: Parser Diagnostic Summary Bar
              if (p.scanStatus.isNotEmpty && p.state != LoadState.loading) ...[
                SizedBox(height: AppSpacing.md),
                Container(
                  padding: EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        color: AppColors.isMonochrome
                            ? AppColors.primary
                            : AppColors.iconOnLight,
                        size: 16,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          p.scanStatus,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (p.hasActiveTransactionFilters) ...[
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${p.activeTransactionFilterCount} filter${p.activeTransactionFilterCount == 1 ? '' : 's'} active',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        p.clearTransactionFilters();
                      },
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Results Count
        if (visibleTxns.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Text(
                  '${visibleTxns.length} transaction${visibleTxns.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

        SizedBox(height: AppSpacing.sm),

        // Transaction List
        Expanded(
          child: visibleTxns.isEmpty
              ? _EmptyTransactions(provider: p)
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                      AppSpacing.screenHorizontal,
                      AppSpacing.scrollBottomDockClearance),
                  itemCount: visibleTxns.length,
                  itemBuilder: (ctx, i) {
                    final txn = visibleTxns[i];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration:
                          Duration(milliseconds: 400 + (i.clamp(0, 10) * 50)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Transform.translate(
                        offset: Offset(30 * (1 - value), 0),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      ),
                      child: Dismissible(
                        key: ValueKey('${txn.id}_$i'),
                        direction: DismissDirection.horizontal,
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.endToStart) {
                            await _editTransaction(context, p, txn);
                            return false; // Don't dismiss for edit
                          } else {
                            return _confirmDelete(context);
                          }
                        },
                        onDismissed: (direction) {
                          if (direction == DismissDirection.startToEnd) {
                            p.deleteTransaction(txn.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Transaction deleted')),
                            );
                          }
                        },
                        // Background for Swipe Right (Delete)
                        background: Container(
                          margin: EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(left: AppSpacing.xl),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HugeIcon(
                                  icon: HugeIcons.strokeRoundedDelete02,
                                  color: AppColors.red,
                                  size: 24),
                              const SizedBox(height: 2),
                              Text('Delete',
                                  style: TextStyle(
                                      color: AppColors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        // Secondary Background for Swipe Left (Edit)
                        secondaryBackground: Container(
                          margin: EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: AppSpacing.xl),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedPencilEdit02,
                                color: AppColors.isMonochrome
                                    ? AppColors.primary
                                    : AppColors.iconOnLight,
                                size: 24,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: AppColors.isMonochrome
                                      ? AppColors.primary
                                      : AppColors.iconOnLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: SleekTransactionTile(
                          formatAmount: p.formatAmount,
                          txn: txn,
                          onEdit: () => _editTransaction(context, p, txn),
                          onDelete: () async {
                            final shouldDelete = await _confirmDelete(context);
                            if (shouldDelete == true && context.mounted) {
                              p.deleteTransaction(txn.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Transaction deleted'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _editTransaction(
    BuildContext context,
    TransactionProvider provider,
    Transaction txn,
  ) async {
    final result = await showManualTransactionSheet(context, initial: txn);
    if (!context.mounted) return;
    if (result != null) {
      provider.updateTransaction(txn.id, result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction updated')),
      );
    }
  }
}

class _EmptyTransactions extends StatelessWidget {
  final TransactionProvider provider;
  const _EmptyTransactions({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasAnyTransactions = provider.transactions.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.xl,
          AppSpacing.screenHorizontal,
          120,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedInbox,
                size: 32,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              hasAnyTransactions
                  ? 'No transactions found'
                  : 'No transactions yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              hasAnyTransactions
                  ? 'Try adjusting your filters'
                  : 'Import or add your first transaction to get started',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!hasAnyTransactions) ...[
              SizedBox(height: AppSpacing.xxl),
              _EmptyActionOption(
                icon: HugeIcons.strokeRoundedMessage01,
                title: 'Scan SMS',
                subtitle: 'Import from bank messages',
                color: AppColors.primary,
                onTap: provider.load,
              ),
              SizedBox(height: AppSpacing.md),
              _EmptyActionOption(
                icon: HugeIcons.strokeRoundedFileAttachment,
                title: 'Import PDF',
                subtitle: 'Upload bank statements',
                color: AppColors.primary,
                onTap: () => _openPdfFlow(context),
              ),
              SizedBox(height: AppSpacing.md),
              _EmptyActionOption(
                icon: HugeIcons.strokeRoundedPencilEdit01,
                title: 'Add Manually',
                subtitle: 'Enter transactions by hand',
                color: AppColors.primary,
                onTap: () => _openManualEntry(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openPdfFlow(BuildContext context) async {
    final mode = await showPdfChunkModeSheet(context);
    if (mode == null) return;
    if (!context.mounted) return;
    context.read<TransactionProvider>().processPdf(mode: mode);
  }

  Future<void> _openManualEntry(BuildContext context) async {
    final draft = await showManualTransactionSheet(context);
    if (draft == null) return;
    if (!context.mounted) return;
    context.read<TransactionProvider>().addManualTransaction(
          merchant: draft.merchant,
          amount: draft.amount,
          type: draft.type,
          category: draft.category,
          bank: draft.bank,
          date: draft.date,
        );
  }
}

class _EmptyActionOption extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _EmptyActionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: AppDecorations.card,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: AppDecorations.iconContainer(color: color),
                child: HugeIcon(
                  icon: icon,
                  color: AppColors.isMonochrome ? color : AppColors.iconOnLight,
                  size: 20,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
                    SizedBox(height: AppSpacing.xs),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SavyitChip(
    label: label,
    variant: SavyitChipVariant.filter,
    selected: isSelected,
    onTap: onTap,
  );
}

class _DropdownChip extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;

  const _DropdownChip({
    required this.hint,
    this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: hasValue ? AppColors.primary : AppColors.border,
          width: AppBorders.normal,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: hasValue ? value : null,
          hint: Text(
            hint,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMain,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: hasValue ? AppColors.primary : AppColors.textMuted,
          ),
          onChanged: onChanged,
          items: [
            DropdownMenuItem(
              value: '',
              child: Text('All $hint'),
            ),
            ...items.map((it) => DropdownMenuItem(value: it, child: Text(it))),
          ],
        ),
      ),
    );
  }
}
