import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/auth_provider.dart';
import 'package:nola_kitchensights_app/providers/my_stores_provider.dart';
import 'home_screen.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'KitchenSights',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                try {
                  // 1) Carrega as lojas da Maria
                  final stores = await ref.read(myStoresProvider.future);
                  if (stores.isEmpty) {
                    throw Exception('Nenhuma loja encontrada para a Maria.');
                  }

                  // 2) Abre um seletor para a Maria escolher a loja padrão
                  final int? chosenId = await _pickDefaultStore(context, stores);
                  if (chosenId == null) return; // usuário cancelou

                  // 3) Reordena storeIds deixando a escolhida em primeiro
                  final allIds = stores.map((s) => s.id).toList();
                  final reordered = <int>[chosenId, ...allIds.where((id) => id != chosenId)];

                  // 4) Faz o impersonate com a loja escolhida na frente
                  ref.read(authProvider.notifier).impersonate(
                        name: 'Maria',
                        storeIds: reordered,
                      );

                  // 5) Navega para o Home
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Falha ao iniciar sessão: $e')),
                    );
                  }
                }
              },
              child: const Text('Entrar como Maria (demo)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<int?> _pickDefaultStore(
    BuildContext context,
    List<KitchenStoreRef> stores,
  ) async {
    int tmp = stores.first.id;

    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Escolha sua loja padrão',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: tmp,
                    decoration: const InputDecoration(
                      labelText: 'Loja',
                      border: OutlineInputBorder(),
                    ),
                    items: stores
                        .map(
                          (s) => DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => tmp = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(ctx).pop(tmp),
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
