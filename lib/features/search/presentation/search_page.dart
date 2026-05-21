import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(filteredReservationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('완료/검색')),
      body: RefreshIndicator(
        triggerMode: RefreshIndicatorTriggerMode.anywhere,
        onRefresh: () async {
          ref.invalidate(allReservationsProvider);
          await ref.read(allReservationsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
            itemsAsync.when(
              data: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '검색 결과 ${items.length}건',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final item in items)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${item.customerName.isEmpty ? '(고객명없음)' : item.customerName} · ${item.carNumber}',
                        ),
                        subtitle: Text(
                          '${item.reservationId} · ${item.tab.label} · ${item.timeLabel}',
                        ),
                        onTap: () =>
                            context.push('/reservation/${item.reservationId}'),
                      ),
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text('검색 데이터를 불러오지 못했습니다.\n$error'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
