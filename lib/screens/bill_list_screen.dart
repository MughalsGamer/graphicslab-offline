import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'add_edit_bill_screen.dart';
import 'bill_detail_dialog.dart';

class BillListScreen extends StatefulWidget {
  const BillListScreen({super.key});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  List<Bill> _bills = [];
  List<Bill> _shown = [];
  List<Category> _cats = [];
  int? _catFilter;
  String _query = '';
  String _sort = 'date_desc';
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
    final b = await DB.I.getBills();
    final c = await DB.I.getCategories();
    if (!mounted) return;
    setState(() {
      _bills = b;
      _cats = c;
      if (_catFilter != null && !c.any((x) => x?.id == _catFilter)) {
        _catFilter = null;
      }
      _loading = false;
      _apply();
    });
  }

  void _apply() {
    final q = _query.toLowerCase();
    _shown = _bills.where((b) {
      final okQ = q.isEmpty ||
          b.partyName.toLowerCase().contains(q) ||
          b.notes.toLowerCase().contains(q) ||
          b.number.toLowerCase().contains(q);
      final okC = _catFilter == null || b.categoryId == _catFilter;
      return okQ && okC;
    }).toList();
    _shown.sort((a, b) {
      switch (_sort) {
        case 'date_asc':
          return a.date.compareTo(b.date);
        case 'amount_desc':
          return b.totalAmount.compareTo(a.totalAmount);
        case 'amount_asc':
          return a.totalAmount.compareTo(b.totalAmount);
        default:
          final c = b.date.compareTo(a.date);
          return c != 0 ? c : (b.id ?? 0).compareTo(a.id ?? 0);
      }
    });
  }

  Future<void> _delete(Bill b) async {
    final ok = await confirmDialog(
        context, 'Delete Bill', 'Delete bill ${b.number} of ${b.partyName}?');
    if (!ok) return;
    await DB.I.deleteBill(b.id!);
    if (mounted) snack(context, 'Bill deleted');
  }

  void _openEditor([int? id]) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => AddEditBillScreen(billId: id)));

  @override
  Widget build(BuildContext context) {
    final totalDisc = _shown.fold(0.0, (s, b) => s + b.totalDiscount);
    final totalRem = _shown.fold(0.0, (s, b) => s + b.remaining);
    return Scaffold(
      appBar: AppBar(title: const Text('Udhaar Bills')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Bill'),
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
                      value: null, child: Text('All', style: TextStyle(fontSize: 13))),
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
                  hintText: 'Search bills...',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Sort',
              color: AppColors.surface,
              icon: const Icon(Icons.sort_rounded, color: AppColors.primary),
              onSelected: (v) => setState(() {
                _sort = v;
                _apply();
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'date_desc', child: Text('Newest First')),
                PopupMenuItem(value: 'date_asc', child: Text('Oldest First')),
                PopupMenuItem(
                    value: 'amount_desc', child: Text('Highest Amount')),
                PopupMenuItem(
                    value: 'amount_asc', child: Text('Lowest Amount')),
              ],
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Expanded(
                child: AmountBox(
                    icon: Icons.receipt_rounded,
                    label: 'Bills',
                    value: '${_shown.length}',
                    color: AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(
                child: AmountBox(
                    icon: Icons.local_offer_rounded,
                    label: 'Discounts',
                    value: 'Rs. ${compact(totalDisc)}',
                    color: AppColors.warning)),
            const SizedBox(width: 8),
            Expanded(
                child: AmountBox(
                    icon: Icons.hourglass_empty_rounded,
                    label: 'Remaining',
                    value: 'Rs. ${compact(totalRem)}',
                    color: AppColors.success)),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _shown.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'No bills found',
                      subtitle: 'Create your first udhaar bill')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                      itemCount: _shown.length,
                      itemBuilder: (_, i) => _card(_shown[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _card(Bill b) {
    final pending = b.remaining > 0;
    final sc = pending ? AppColors.warning : AppColors.success;
    final cc = categoryColor(b.categoryName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => showBillDetail(context, b.id!),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                  b.partyName.isNotEmpty ? b.partyName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.partyName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('${b.number}  •  ${fmtDate(b.date)}',
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.textMuted)),
                          if (b.categoryName.isNotEmpty)
                            SmallChip(b.categoryName, cc),
                        ]),
                  ]),
            ),
            IconBtn(
                icon: Icons.edit_rounded,
                color: Colors.orange.shade300,
                tooltip: 'Edit',
                onTap: () => _openEditor(b.id)),
            const SizedBox(width: 8),
            IconBtn(
                icon: Icons.delete_outline_rounded,
                color: AppColors.danger,
                tooltip: 'Delete',
                onTap: () => _delete(b)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: AmountBox(
                    icon: Icons.receipt_outlined,
                    label: 'Total',
                    value: money(b.totalAmount),
                    color: AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(
                child: AmountBox(
                    icon: Icons.local_offer_outlined,
                    label: 'Discount',
                    value: money(b.totalDiscount),
                    color: AppColors.warning)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: sc.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sc.withOpacity(0.25)),
            ),
            child: Row(children: [
              Icon(pending ? Icons.hourglass_empty_rounded : Icons.done_all_rounded,
                  size: 15, color: sc),
              const SizedBox(width: 7),
              Text(pending ? 'Remaining' : 'Fully Paid',
                  style: TextStyle(
                      fontSize: 12,
                      color: sc.withOpacity(0.85),
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(money(b.remaining),
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: sc)),
            ]),
          ),
        ]),
      ),
    );
  }
}
