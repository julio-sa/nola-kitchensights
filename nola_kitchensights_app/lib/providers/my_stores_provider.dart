// lib/providers/my_stores_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

class KitchenStoreRef {
  final int id;
  final String name;

  const KitchenStoreRef({
    required this.id,
    required this.name,
  });
}

/// Provider que devolve só as lojas da usuária logada (ex: Maria).
/// HOJE está mockado. Depois é só trocar pelo endpoint real.
final myStoresProvider = FutureProvider<List<KitchenStoreRef>>((ref) async {
  // Mantive nomes plausíveis pros IDs que você já usou (97 etc)
  return const [
    KitchenStoreRef(id: 97, name: 'Nola Centro'),
    KitchenStoreRef(id: 101, name: 'Nola Shopping'),
    KitchenStoreRef(id: 203, name: 'Nola Zona Sul'),
  ];
});
