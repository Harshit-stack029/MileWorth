import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'add_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    // Load on first open; harmless if already loaded.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().fetchExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currency = state.user?.currency ?? 'USD';
    final total = state.expenses.fold<double>(0, (s, e) => s + e.amount);

    return RefreshIndicator(
      onRefresh: state.fetchExpenses,
      child: state.expenses.isEmpty
          ? ListView(children: [
              const SizedBox(height: 120),
              Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Center(child: Text('No expenses yet', style: Theme.of(context).textTheme.titleMedium)),
              const SizedBox(height: 8),
              const Center(child: Text('Track fuel, tolls and supplies with the + button.')),
            ])
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: AppColors.money.withValues(alpha: 0.08),
                  child: ListTile(
                    leading: const Icon(Icons.summarize, color: AppColors.money),
                    title: const Text('Total expenses'),
                    trailing: Text(formatMoney(total, currency),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: AppColors.money, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                for (final e in state.expenses) _ExpenseTile(expense: e),
              ],
            ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  const _ExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final currency = state.user?.currency ?? 'USD';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(expense.hasReceipt ? Icons.receipt : Icons.payments_outlined,
              color: AppColors.primary, size: 20),
        ),
        title: Text(expense.vendor ?? 'Expense',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${formatDate(expense.date)}${expense.category != null ? ' · ${expense.category}' : ''}',
        ),
        trailing: Text(formatMoney(expense.amount, currency),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        onLongPress: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete expense?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
              ],
            ),
          );
          if (ok == true) await state.deleteExpense(expense);
        },
      ),
    );
  }
}

/// FAB target used by the home shell.
void openAddExpense(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
  );
}
