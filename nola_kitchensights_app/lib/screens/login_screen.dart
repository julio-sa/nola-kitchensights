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
                  // Busca as lojas da Maria no provider (chama o endpoint /maria/stores)
                  final stores = await ref.read(myStoresProvider.future);
                  final storeIds = stores.map((s) => s.id).toList();

                  // Faz o impersonate com os IDs vindos do backend
                  ref.read(authProvider.notifier).impersonate(
                        name: 'Maria',
                        storeIds: storeIds,
                      );

                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Falha ao carregar lojas da Maria: $e',
                        ),
                      ),
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
}
