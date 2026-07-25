import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../providers/app_controller.dart';
import '../providers/derived.dart';
import '../widgets/common.dart';
import 'loan_detail_screen.dart';
import 'map_screen.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(todayCollectionsProvider);
    final total = items.fold<double>(0, (s, e) => s + e.amount);
    final overdue = items.where((e) => e.overdue).length;

    return Scaffold(
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.task_alt,
              title: 'Nada para cobrar hoje',
              message: 'Todas as cobranças estão em dia. 🎉')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Card(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(.4),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _summary('A cobrar', '${items.length}'),
                          _summary('Atrasadas', '$overdue'),
                          _summary('Total', Formatters.moneyCompact(total)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      return Card(
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    LoanDetailScreen(loanId: it.loan.id)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                            child: Row(
                              children: [
                                ClientAvatar(
                                    name: it.client.name,
                                    photoPath: it.client.photoPath),
                                const SizedBox(width: 12),
                                // Expanded garante largura ao texto: o nome do
                                // cliente nunca quebra na vertical.
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(it.client.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${it.loan.type.label} • ${Formatters.money(it.amount)}'
                                        '${it.overdue ? ' • ATRASADA' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: it.overdue
                                                ? AppTheme.negative
                                                : null),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    minimumSize: const Size(0, 36),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () async {
                                    final notifier =
                                        ref.read(appProvider.notifier);
                                    if (it.isPledge) {
                                      // Penhor: registra o pagamento de juros.
                                      await notifier
                                          .registerPledgeInterest(it.loan.id);
                                    } else {
                                      await notifier.settleInstallment(
                                          it.loan.id, it.installment!.number);
                                    }
                                  },
                                  child: Text(it.isPledge ? 'Receber' : 'Baixar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MapScreen())),
        icon: const Icon(Icons.map),
        label: const Text('Mapa'),
      ),
    );
  }

  Widget _summary(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}
