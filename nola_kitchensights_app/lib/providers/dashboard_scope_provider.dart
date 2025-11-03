// lib/providers/dashboard_scope_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/my_stores_provider.dart';

/// Estado do escopo global do dashboard
class DashboardScope {
  final int primaryStoreId;
  final int? compareStoreId; // opcional p/ comparativos
  final DateTimeRange range;

  const DashboardScope({
    required this.primaryStoreId,
    required this.range,
    this.compareStoreId,
  });

  DashboardScope copyWith({
    int? primaryStoreId,
    int? compareStoreId,
    DateTimeRange? range,
    bool clearCompare = false,
  }) {
    return DashboardScope(
      primaryStoreId: primaryStoreId ?? this.primaryStoreId,
      compareStoreId: clearCompare ? null : (compareStoreId ?? this.compareStoreId),
      range: range ?? this.range,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DashboardScope &&
        other.primaryStoreId == primaryStoreId &&
        other.compareStoreId == compareStoreId &&
        other.range.start == range.start &&
        other.range.end == range.end;
  }

  @override
  int get hashCode => Object.hash(primaryStoreId, compareStoreId, range.start, range.end);
}

class DashboardScopeNotifier extends StateNotifier<DashboardScope> {
  final Ref ref;

  DashboardScopeNotifier(this.ref)
      : super(
          DashboardScope(
            primaryStoreId: 0, // placeholder até carregar lojas
            range: DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
          ),
        ) {
    // Assim que as lojas da Maria chegarem, definimos defaults elegantes
    ref.listen<AsyncValue<List<KitchenStoreRef>>>(
      myStoresProvider,
      (prev, next) {
        next.whenData((stores) {
          if (stores.isNotEmpty) {
            final current = state;
            // Se ainda não setamos uma loja real (0 = placeholder), usamos a primeira
            if (current.primaryStoreId == 0) {
              state = current.copyWith(primaryStoreId: stores.first.id);
            }
            // Se compareStoreId for igual à primary, limpamos
            if (current.compareStoreId != null &&
                current.compareStoreId == state.primaryStoreId) {
              state = current.copyWith(clearCompare: true);
            }
          }
        });
      },
    );
  }

  // Setters granulares
  void setPrimaryStore(int id) {
    // evita compare == primary
    final clearCompare = (state.compareStoreId == id);
    state = state.copyWith(primaryStoreId: id, clearCompare: clearCompare);
  }

  void setCompareStore(int? id) {
    // se null => limpa; se igual à primary => ignora/limpa
    if (id == null || id == state.primaryStoreId) {
      state = state.copyWith(clearCompare: true);
    } else {
      state = state.copyWith(compareStoreId: id);
    }
  }

  void clearCompare() {
    state = state.copyWith(clearCompare: true);
  }

  void setRange(DateTimeRange range) {
    state = state.copyWith(range: range);
  }

  void setAll({
    required int primaryStoreId,
    int? compareStoreId,
    required DateTimeRange range,
  }) {
    // normaliza compare != primary
    final normalizedCompare =
        (compareStoreId != null && compareStoreId != primaryStoreId)
            ? compareStoreId
            : null;
    state = DashboardScope(
      primaryStoreId: primaryStoreId,
      compareStoreId: normalizedCompare,
      range: range,
    );
  }
}

/// Provider público
final dashboardScopeProvider =
    StateNotifierProvider<DashboardScopeNotifier, DashboardScope>(
  (ref) => DashboardScopeNotifier(ref),
);
