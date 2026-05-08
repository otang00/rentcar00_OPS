import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(filteredReservationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('완료/검색')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: '고객명 / 차량번호 / 예약ID 검색',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 16),
          Text(
            '검색 결과 ${items.length}건',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Card(
              child: ListTile(
                title: Text('${item.customerName} · ${item.carNumber}'),
                subtitle: Text(
                  '${item.reservationId} · ${item.tab.label} · ${item.timeLabel}',
                ),
                onTap: () => context.push('/reservation/${item.reservationId}'),
              ),
            ),
        ],
      ),
    );
  }
}
