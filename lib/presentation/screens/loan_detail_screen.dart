import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/installment.dart';
import '../../data/models/loan.dart';
import '../providers/app_controller.dart';
import '../widgets/common.dart';

class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({super.key, required this.loanId});
  final String loanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final loan = state.loans.where((l) => l.id == loanId).firstOrNull;
    if (loan == null) {
      return const Scaffold(body: Center(child: Text('Empréstimo removido.')));
    }
    final client = state.clientById(loan.clientId);

    return Scaffold(
      appBar: AppBar(
        title: Text('${loan.type.label} • ${client?.name ?? ''}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'close') {
                final ok = await _confirm(context, 'Encerrar empréstimo?',
                    'O empréstimo será marcado como encerrado.');
                if (ok) await ref.read(appProvider.notifier).closeLoan(loanId);
              } else if (v == 'delete') {
                final ok = await _confirm(context, 'Excluir empréstimo?',
                    'Esta ação não pode ser desfeita.');
                if (ok) {
                  await ref.read(appProvider.notifier).deleteLoan(loanId);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              if (loan.status != LoanStatus.closed)
                const PopupMenuItem(value: 'close', child: Text('Encerrar')),
              const PopupMenuItem(value: 'delete', child: Text('Excluir')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(loan: loan),
          const SizedBox(height: 16),
          if (loan.type == LoanType.pledge)
            _PledgeSection(loan: loan)
          else
            _ScheduleSection(loan: loan),
        ],
      ),
    );
  }

  static Future<bool> _confirm(
      BuildContext context, String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmar')),
            ],
          ),
        ) ??
        false;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(Formatters.money(loan.capital),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                StatusChip(label: loan.status.label),
              ],
            ),
            const SizedBox(height: 4),
            Text('Capital emprestado • início ${Formatters.date(loan.startDate)}',
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 24),
            Row(
              children: [
                _kv(context, 'Taxa', Formatters.percent(loan.interestRate)),
                _kv(context, 'Recebido',
                    Formatters.money(loan.amountReceived)),
                _kv(context, 'Em aberto',
                    Formatters.money(loan.amountOutstanding)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(v,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      );
}

// ------------------------------------------------------------------ pledge

class _PledgeSection extends ConsumerWidget {
  const _PledgeSection({required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: scheme.primaryContainer.withOpacity(.35),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Juros por período',
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text(Formatters.money(loan.interestAmount),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Juros já recebidos',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(Formatters.money(loan.pledgeInterestPaid),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (loan.pledgeDueDate != null && loan.status != LoanStatus.closed) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                loan.status == LoanStatus.overdue
                    ? Icons.error
                    : Icons.event,
                size: 18,
                color: loan.status == LoanStatus.overdue
                    ? AppTheme.negative
                    : AppTheme.neutral,
              ),
              const SizedBox(width: 6),
              Text(
                loan.status == LoanStatus.overdue
                    ? 'Juros atrasado desde ${Formatters.date(loan.pledgeDueDate!)}'
                    : 'Próximo juros vence ${Formatters.date(loan.pledgeDueDate!)}',
                style: TextStyle(
                    fontSize: 13,
                    color: loan.status == LoanStatus.overdue
                        ? AppTheme.negative
                        : null),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (loan.status != LoanStatus.closed)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _receiveInterest(context, ref),
                  icon: const Icon(Icons.payments),
                  label: const Text('Receber juros'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await LoanDetailScreen._confirm(context,
                        'Encerrar empréstimo?',
                        'O cliente devolveu o capital de ${Formatters.money(loan.capital)}?');
                    if (ok) {
                      await ref.read(appProvider.notifier).closeLoan(loan.id);
                    }
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Encerrar'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        const SectionTitle('Histórico de juros'),
        if (loan.interestPayments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Nenhum pagamento de juros ainda.')),
          )
        else
          ...loan.interestPayments.reversed.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.trending_up)),
                  title: Text(Formatters.money(p.amount)),
                  subtitle: Text(
                      '${Formatters.dateTime(p.paidAt)}${p.note.isNotEmpty ? ' • ${p.note}' : ''}'),
                ),
              )),
      ],
    );
  }

  Future<void> _receiveInterest(BuildContext context, WidgetRef ref) async {
    final amountCtrl =
        TextEditingController(text: loan.interestAmount.toStringAsFixed(2));
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Receber juros'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Observação'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok == true) {
      final value =
          double.tryParse(amountCtrl.text.replaceAll(',', '.')) ??
              loan.interestAmount;
      await ref
          .read(appProvider.notifier)
          .registerPledgeInterest(loan.id, amount: value, note: noteCtrl.text.trim());
    }
  }
}

// ---------------------------------------------------------------- schedule

class _ScheduleSection extends ConsumerWidget {
  const _ScheduleSection({required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = loan.schedule.isEmpty
        ? 0.0
        : loan.paidCount / loan.schedule.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('${loan.paidCount}/${loan.schedule.length} pagas'),
                    const Spacer(),
                    Text(Formatters.money(loan.scheduledOutstanding),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                      value: progress, minHeight: 10),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle(loan.type == LoanType.daily ? 'Agenda diária' : 'Parcelas'),
        ...loan.schedule.map((inst) => _InstallmentTile(
              loan: loan,
              inst: inst,
            )),
      ],
    );
  }
}

class _InstallmentTile extends ConsumerWidget {
  const _InstallmentTile({required this.loan, required this.inst});
  final Loan loan;
  final LoanInstallment inst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppTheme.statusColor(inst.status.label);
    final icon = switch (inst.status) {
      PaymentStatus.paid => Icons.check_circle,
      PaymentStatus.overdue => Icons.error,
      PaymentStatus.future => Icons.schedule,
    };
    final label = loan.type == LoanType.daily ? 'Dia' : 'Parcela';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            // Indicador de status: verde (pago) / vermelho (atrasado) / cinza (futuro)
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(.12),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            // Bloco central dentro de Expanded: garante largura e NUNCA
            // quebra o texto na vertical.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$label ${inst.number}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    inst.isPaid && inst.paidAt != null
                        ? 'Pago em ${Formatters.date(inst.paidAt!)}'
                        : 'Vence ${Formatters.date(inst.dueDate)} • ${inst.status.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Valor + ação, com largura mínima (não invade o texto).
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Formatters.money(inst.amount),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                inst.isPaid
                    ? TextButton.icon(
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.undo, size: 16),
                        label: const Text('Estornar'),
                        onPressed: () => ref
                            .read(appProvider.notifier)
                            .undoInstallment(loan.id, inst.number),
                      )
                    : FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          await ref
                              .read(appProvider.notifier)
                              .settleInstallment(loan.id, inst.number);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Pagamento registrado.')),
                            );
                          }
                        },
                        child: const Text('Baixar'),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
