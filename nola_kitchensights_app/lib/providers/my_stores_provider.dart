// lib/providers/my_stores_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// DTO simples usado pela UI (evita espalhar shapes de payload pelo app)
class KitchenStoreRef {
  final int id;
  final String name;

  const KitchenStoreRef({required this.id, required this.name});
}

/// Base dos widgets (mesmo host usado em widget_provider.dart)
const String _baseUrl = 'http://localhost:8000/api/v1/widgets';

Uri _buildUri(String endpoint, [Map<String, String>? query]) {
  final uri = Uri.parse('$_baseUrl/$endpoint');
  return query == null ? uri : uri.replace(queryParameters: query);
}

/// Provider que retorna as lojas da usuária "Maria" vindas do backend.
/// Endpoint: GET /api/v1/widgets/maria/stores
///
/// Payload esperado:
/// {
///   "owner": "Maria",
///   "stores": [ { "store_id": 71, "store_name": "..." }, ... ],
///   ...
/// }
final myStoresProvider = FutureProvider<List<KitchenStoreRef>>((ref) async {
  final client = http.Client();
  try {
    final resp = await client.get(_buildUri('maria/stores'));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final body = jsonDecode(resp.body);
    final List<dynamic> stores = (body is Map<String, dynamic>)
        ? (body['stores'] as List<dynamic>? ?? const [])
        : (body is List ? body : const []);

    // mapeia e normaliza (id, nome), deduplica por id e filtra nomes vazios
    final seen = <int>{};
    final result = <KitchenStoreRef>[];

    for (final raw in stores) {
      if (raw is! Map) continue;
      final idAny = raw['store_id'] ?? raw['id'];
      final nameAny = raw['store_name'] ?? raw['name'];

      int? id;
      if (idAny is int) id = idAny;
      if (idAny is num) id = idAny.toInt();
      if (idAny is String) id = int.tryParse(idAny);

      if (id == null) continue;

      String name = (nameAny?.toString() ?? '').trim();
      if (name.isEmpty) name = 'Loja #$id';

      if (seen.add(id)) {
        result.add(KitchenStoreRef(id: id, name: name));
      }
    }

    // garante lista não vazia (evita problemas nos Dropdowns)
    return result;
  } catch (_) {
    // Em caso de erro, retorna lista vazia (UI lida com loading/empty)
    return const <KitchenStoreRef>[];
  } finally {
    client.close();
  }
});
