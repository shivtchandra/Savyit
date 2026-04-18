import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/budget_bucket.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';

class BudgetBucketsScreen extends StatelessWidget {
  const BudgetBucketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Occasion Budgets'),
        actions: [
          IconButton(
            tooltip: 'Create budget',
            onPressed: () => _showCreateBudgetSheet(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: provider.budgetBuckets.isEmpty
          ? _EmptyBudgetState(onCreate: () => _showCreateBudgetSheet(context))
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              itemCount: provider.budgetBuckets.length,
              itemBuilder: (context, index) {
                final bucket = provider.budgetBuckets[index];
                return _BudgetCard(bucket: bucket);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateBudgetSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Budget'),
      ),
    );
  }

  Future<void> _showCreateBudgetSheet(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final sym = context.read<TransactionProvider>().selectedCurrency;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.sheetChrome,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.sheet),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Occasion Budget',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Goa Trip, Wedding, Birthday, Festival...',
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Budget Amount',
                    prefixText: '$sym ',
                    hintText: 'e.g. 25000',
                  ),
                ),
                SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final amount = double.tryParse(
                        amountCtrl.text
                            .replaceAll(RegExp(r'[^0-9.]'), ''),
                      );
                      if (name.isEmpty || amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter a valid name and budget amount',
                            ),
                          ),
                        );
                        return;
                      }
                      await context
                          .read<TransactionProvider>()
                          .createBudgetBucket(
                            name: name,
                            targetAmount: amount,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Create Budget'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetBucket bucket;
  const _BudgetCard({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final spent = provider.spentForBucket(bucket);
    final linkedCount = provider.transactionsForBucket(bucket).length;
    final progress = bucket.targetAmount <= 0
        ? 0.0
        : (spent / bucket.targetAmount).clamp(0.0, 1.0);
    final overBudget = spent > bucket.targetAmount;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedTarget02,
                  color: AppColors.isMonochrome
                      ? AppColors.primary
                      : AppColors.iconOnLight,
                  size: 20,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bucket.name,
                        style: Theme.of(context).textTheme.labelLarge),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      '$linkedCount linked transaction${linkedCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete budget?'),
                        content: const Text(
                          'This will remove the budget only. Transactions will stay.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              'Delete',
                              style: TextStyle(color: AppColors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (shouldDelete == true) {
                      if (!context.mounted) return;
                      await context
                          .read<TransactionProvider>()
                          .deleteBudgetBucket(bucket.id);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete budget')),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                'Spent: ${provider.formatAmount(spent)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: overBudget ? AppColors.red : AppColors.textMain,
                ),
              ),
              const Spacer(),
              Text(
                'Target: ${provider.formatAmount(bucket.targetAmount)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(
                overBudget ? AppColors.red : AppColors.primary,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BudgetBucketDetailScreen(bucketId: bucket.id),
                  ),
                );
              },
              icon: const Icon(Icons.playlist_add_check_rounded),
              label: const Text('Manage Transactions'),
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetBucketDetailScreen extends StatelessWidget {
  final String bucketId;
  const BudgetBucketDetailScreen({super.key, required this.bucketId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final bucket = provider.getBucketById(bucketId);
    if (bucket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Budget')),
        body: const Center(child: Text('This budget no longer exists.')),
      );
    }

    final linked = provider.transactionsForBucket(bucket);
    final spent = provider.spentForBucket(bucket);
    final left = (bucket.targetAmount - spent);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(bucket.name)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: AppDecorations.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Target: ${provider.formatAmount(bucket.targetAmount)}'),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Spent: ${provider.formatAmount(spent)}',
                  style: TextStyle(
                    color: spent > bucket.targetAmount
                        ? AppColors.red
                        : AppColors.textMain,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  left >= 0
                      ? 'Remaining: ${provider.formatAmount(left)}'
                      : 'Over by: ${provider.formatAmount(left.abs())}',
                  style: TextStyle(
                    color: left >= 0 ? AppColors.green : AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final selected = await showModalBottomSheet<List<String>>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _TransactionPickerSheet(
                          initialSelection: bucket.transactionIds,
                        ),
                      );
                      if (selected != null && context.mounted) {
                        await context
                            .read<TransactionProvider>()
                            .setBudgetBucketTransactions(bucket.id, selected);
                      }
                    },
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: const Text('Add Existing Transactions'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Linked Transactions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: AppSpacing.sm),
          if (linked.isEmpty)
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: AppDecorations.card,
              child: Text(
                'No transactions linked yet. Add from your SMS/manual/PDF history.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ...linked.map(
            (txn) => _LinkedTxnTile(
              bucketId: bucket.id,
              txn: txn,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedTxnTile extends StatelessWidget {
  final String bucketId;
  final Transaction txn;
  const _LinkedTxnTile({required this.bucketId, required this.txn});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    final date = DateFormat('dd MMM yyyy').format(txn.date);
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: AppDecorations.card,
      child: ListTile(
        leading: Icon(
          txn.isCredit
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded,
          color: txn.isCredit ? AppColors.green : AppColors.red,
        ),
        title: Text(
          txn.merchant,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('$date • ${txn.bank}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${txn.isCredit ? '+' : '-'}${p.formatAmount(txn.amount)}',
              style: TextStyle(
                color: txn.isCredit ? AppColors.green : AppColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              onPressed: () {
                context.read<TransactionProvider>().removeTransactionFromBucket(
                      bucketId,
                      txn.id,
                    );
              },
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.textMuted,
              ),
              tooltip: 'Unlink',
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionPickerSheet extends StatefulWidget {
  final List<String> initialSelection;
  const _TransactionPickerSheet({required this.initialSelection});

  @override
  State<_TransactionPickerSheet> createState() =>
      _TransactionPickerSheetState();
}

class _TransactionPickerSheetState extends State<_TransactionPickerSheet> {
  late Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final transactions = provider.transactions.where((txn) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return txn.merchant.toLowerCase().contains(q) ||
          txn.category.toLowerCase().contains(q) ||
          txn.bank.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.sheetChrome,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Select Transactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selected.clear()),
                child: const Text('Clear'),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          TextField(
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: const InputDecoration(
              hintText: 'Search merchant/category/bank',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_selected.length} selected',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('No transactions found'))
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final txn = transactions[index];
                      final checked = _selected.contains(txn.id);
                      final fmt = context.watch<TransactionProvider>().formatAmount;
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(txn.id);
                            } else {
                              _selected.remove(txn.id);
                            }
                          });
                        },
                        title: Text(
                          txn.merchant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${DateFormat('dd MMM').format(txn.date)} • ${txn.category}',
                        ),
                        secondary: Text(
                          '${txn.isCredit ? '+' : '-'}${fmt(txn.amount)}',
                          style: TextStyle(
                            color:
                                txn.isCredit ? AppColors.green : AppColors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selected.toList()),
              child: const Text('Save Selection'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBudgetState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyBudgetState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedTarget02,
                color: AppColors.isMonochrome
                    ? AppColors.primary
                    : AppColors.iconOnLight,
                size: 30,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Create your first occasion budget',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Set a budget for a trip, festival, or event and track it using transactions already in your app.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Budget'),
            ),
          ],
        ),
      ),
    );
  }
}
