import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'ledger_screen.dart';
import 'party_dialogs.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  List<Party> _all = [];
  List<Party> _shown = [];
  List<Category> _cats = [];
  Map<int, double> _bal = {};
  int? _catFilter;
  String _query = '';
  String _sort = 'name_asc';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    DB.I.changes.addListener(_load);
  }

  @override
  void dispose() {
    DB.I.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final p = await DB.I.getParties();
    final c = await DB.I.getCategories();
    final b = await DB.I.partyBalances();
    if (!mounted) return;
    setState(() {
      _all = p;
      _cats = c;
      _bal = b;
      if (_catFilter != null && !c.any((x) => x.id == _catFilter)) {
        _catFilter = null;
      }
      _loading = false;
      _apply();
    });
  }

  void _apply() {
    final q = _query.toLowerCase();
    _shown = _all.where((p) {
      final okQ = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.phone.contains(q) ||
          p.email.toLowerCase().contains(q);
      final okC = _catFilter == null || p.categoryId == _catFilter;
      return okQ && okC;
    }).toList();
    double b(Party p) => _bal[p.id] ?? 0;
    _shown.sort((x, y) {
      switch (_sort) {
        case 'name_desc':
          return y.name.toLowerCase().compareTo(x.name.toLowerCase());
        case 'bal_desc':
          return b(y).compareTo(b(x));
        case 'bal_asc':
          return b(x).compareTo(b(y));
        default:
          return x.name.toLowerCase().compareTo(y.name.toLowerCase());
      }
    });
  }

  Future<void> _delete(Party p) async {
    final ok = await confirmDialog(context, 'Delete Customer',
        'Delete "${p.name}" along with all his bills, payments and discounts?');
    if (!ok) return;
    await DB.I.deleteParty(p.id!);
    if (mounted) snack(context, 'Customer deleted');
  }

  void _ledger(Party p) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => LedgerScreen(party: p)));

  @override
  Widget build(BuildContext context) {
    final pending = _all.where((p) => (_bal[p.id] ?? 0) > 0.005).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPartyForm(context, categoryId: _catFilter),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Customer'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<int?>(
                value: _catFilter,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_rounded,
                        size: 16, color: AppColors.textSecondary)),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All', style: TextStyle(fontSize: 13))),
                  ..._cats.map((c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(c.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)))),
                ],
                onChanged: (v) => setState(() {
                  _catFilter = v;
                  _apply();
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() {
                  _query = v;
                  _apply();
                }),
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search customers...',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Sort',
              color: AppColors.surface,
              icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
              onSelected: (v) => setState(() {
                _sort = v;
                _apply();
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'name_asc', child: Text('Name A → Z')),
                PopupMenuItem(value: 'name_desc', child: Text('Name Z → A')),
                PopupMenuItem(value: 'bal_desc', child: Text('Highest Balance')),
                PopupMenuItem(value: 'bal_asc', child: Text('Lowest Balance')),
              ],
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Expanded(
                child: AmountBox(
                    icon: Icons.people_alt_rounded,
                    label: 'Total',
                    value: '${_all.length}',
                    color: AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(
                child: AmountBox(
                    icon: Icons.hourglass_top_rounded,
                    label: 'Pending',
                    value: '$pending',
                    color: AppColors.danger)),
            const SizedBox(width: 8),
            Expanded(
                child: AmountBox(
                    icon: Icons.check_circle_rounded,
                    label: 'Cleared',
                    value: '${_all.length - pending}',
                    color: AppColors.success)),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _shown.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_alt_outlined,
                      title: 'No customers found',
                      subtitle:
                          'Add a customer here or register one while making a bill')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                      itemCount: _shown.length,
                      itemBuilder: (_, i) => _card(_shown[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _card(Party p) {
    final bal = _bal[p.id] ?? 0;
    final has = bal > 0.005;
    final cc = categoryColor(p.categoryName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => _ledger(p),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [cc, cc.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(p.name[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (p.categoryName.isNotEmpty)
                          SmallChip(p.categoryName, cc),
                        if (p.phone.isNotEmpty)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.phone_rounded,
                                size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(p.phone,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ]),
                      ]),
                ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (has ? AppColors.danger : AppColors.success)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: (has ? AppColors.danger : AppColors.success)
                      .withOpacity(0.3)),
            ),
            child: Text(money(bal),
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: has ? AppColors.danger : AppColors.success)),
          ),
          PopupMenuButton<String>(
            color: AppColors.surface,
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            onSelected: (v) async {
              if (v == 'ledger') _ledger(p);
              if (v == 'edit') await showPartyForm(context, party: p);
              if (v == 'delete') await _delete(p);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'ledger',
                  child: ListTile(
                      dense: true,
                      leading: Icon(Icons.menu_book_rounded,
                          color: AppColors.success),
                      title: Text('View Ledger'))),
              PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                      dense: true,
                      leading:
                          Icon(Icons.edit_outlined, color: AppColors.warning),
                      title: Text('Edit'))),
              PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger),
                      title: Text('Delete'))),
            ],
          ),
        ]),
      ),
    );
  }
}
