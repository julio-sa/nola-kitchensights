import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/my_stores_provider.dart';
import '../services/api_service.dart';
import '../widgets/at_risk_customers_widget.dart';
import '../widgets/delivery_heatmap_widget.dart';
import '../widgets/revenue_overview_widget.dart';
import '../widgets/store_comparison_widget.dart';
import '../widgets/top_products_widget.dart';
import 'graphs_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _selectedStore;
  int? _comparisonStore;
  late DateTimeRange _dateRange;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _selectedStore = authState.storeIds.first;
    _comparisonStore =
        authState.storeIds.length > 1 ? authState.storeIds[1] : null;
    final now = DateTime.now();
    _dateRange =
        DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);
  }

  Future<void> _pickDateRange() async {
    final newRange = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (newRange != null) {
      setState(() => _dateRange = newRange);
    }
  }

  List<int> _availableComparisonStores(List<int> storeIds) {
    return storeIds.where((id) => id != _selectedStore).toList();
  }

  Future<void> _exportReport(List<int> storeIds) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final csv = await ApiService.exportStorePerformance(
        storeIds: storeIds,
        startDate: _dateRange.start,
        endDate: _dateRange.end,
      );
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Relatório gerado e copiado para a área de transferência.')),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar: $err')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _storeLabel(
      AsyncValue<List<KitchenStoreRef>> storesAsync, int id) {
    return storesAsync.maybeWhen(
      data: (stores) {
        final found = stores.where((s) => s.id == id);
        if (found.isNotEmpty) return 'Loja ${found.first.name}';
        return 'Loja #$id';
      },
      orElse: () => 'Loja #$id',
    );
  }

  Future<void> _openStorePicker() async {
    try {
      final stores = await ref.read(myStoresProvider.future);
      if (!mounted) return;

      final pickedId = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Text('Trocar loja',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (_, idx) {
                      final s = stores[idx];
                      final selected = s.id == _selectedStore;
                      return ListTile(
                        leading: const Icon(Icons.storefront),
                        title: Text('Loja ${s.name}'),
                        subtitle: Text('ID: ${s.id}'),
                        trailing: selected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () => Navigator.of(ctx).pop(s.id),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: stores.length,
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (pickedId != null) {
        setState(() {
          _selectedStore = pickedId;
          final authState = ref.read(authProvider);
          final options =
              _availableComparisonStores(authState.storeIds);
          if (_comparisonStore != null &&
              !options.contains(_comparisonStore)) {
            _comparisonStore =
                options.isEmpty ? null : options.first;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível carregar lojas: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final storesAsync = ref.watch(myStoresProvider);

    final storeIds = authState.storeIds;
    final comparisonOptions = _availableComparisonStores(storeIds);

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${authState.userName}!'),
        actions: [
          IconButton(
            tooltip: 'Trocar loja',
            onPressed: _openStorePicker,
            icon: const Icon(Icons.storefront),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    DropdownButton<int>(
                      value: _selectedStore,
                      items: storeIds
                          .map(
                            (id) => DropdownMenuItem(
                              value: id,
                              child: Text(_storeLabel(storesAsync, id)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedStore = value;
                          final newOptions =
                              _availableComparisonStores(storeIds);
                          if (_comparisonStore != null &&
                              !newOptions.contains(_comparisonStore)) {
                            _comparisonStore =
                                newOptions.isEmpty ? null : newOptions.first;
                          }
                        });
                      },
                    ),
                    if (comparisonOptions.isNotEmpty)
                      DropdownButton<int>(
                        value: comparisonOptions.contains(_comparisonStore)
                            ? _comparisonStore
                            : null,
                        hint: const Text('Comparar com...'),
                        items: comparisonOptions
                            .map(
                              (id) => DropdownMenuItem(
                                value: id,
                                child: Text(_storeLabel(storesAsync, id)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _comparisonStore = value),
                      ),
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                          '${_formatDate(_dateRange.start)} - ${_formatDate(_dateRange.end)}'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final ids = <int>{
                          _selectedStore,
                          if (_comparisonStore != null) _comparisonStore!,
                        }.toList()
                          ..sort();
                        _exportReport(ids);
                      },
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.file_download),
                      label: Text(
                          _isExporting ? 'Exportando...' : 'Exportar CSV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GraphsScreen(
                              storeId: _selectedStore,
                              startDate: _dateRange.start,
                              endDate: _dateRange.end,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Ver gráficos'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RevenueOverviewWidget(
                  storeId: _selectedStore,
                  startDate: _dateRange.start,
                  endDate: _dateRange.end,
                ),
                const SizedBox(height: 16),
                TopProductsWidget(storeId: _selectedStore),
                const SizedBox(height: 16),
                DeliveryHeatmapWidget(storeId: _selectedStore),
                const SizedBox(height: 16),
                AtRiskCustomersWidget(storeId: _selectedStore),
                const SizedBox(height: 16),
                if (_comparisonStore != null)
                  StoreComparisonWidget(
                    storeA: _selectedStore,
                    storeB: _comparisonStore!,
                    startDate: _dateRange.start,
                    endDate: _dateRange.end,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
