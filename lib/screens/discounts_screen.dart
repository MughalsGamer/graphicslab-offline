import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'party_dialogs.dart';

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  List<DiscountRec> _all = [];
  String _q = '';
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
    final l = await DB.I.getDiscounts();
    if (mounted) {
      setState(() {
        _all = l;
        _loading = false;
      });
    }
  }

  Future<void> _delete(DiscountRec d) async {
    final ok = await confirmDialog(context, 'Delete Discount',
        'Delete discount of ${money(d.amount)} given to ${d.partyName}?');
    if (!ok) return;
    await DB.I.deleteDiscount(d.id!);
    if (mounted) snack(context, 'Discount deleted');
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = _all
        .where((d) => q.isEmpty || d.partyName.toLowerCase().contains(q))
        .toList();
    final total = list.fold(0.0, (s, d) => s + d.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Discounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
            context: context, builder: (_) => const DiscountForm()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Give Discount'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Search discounts...',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 170,
              child: AmountBox(
                  icon: Icons.local_offer_rounded,
                  label: 'Total discount',
                  value: money(total),
                  color: AppColors.warning),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? const EmptyState(
                      icon: Icons.local_offer_outlined,
                      title: 'No discounts yet',
                      subtitle: 'Give a discount to a customer')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final d = list[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            child: Row(children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.local_offer_rounded,
                                    color: AppColors.warning),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(d.partyName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700)),
                                      Text(
                                          [
                                            fmtDate(d.date),
                                            if (d.reference.isNotEmpty)
                                              'Ref: ${d.reference}'
                                          ].join('  •  '),
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textMuted)),
                                      if (d.notes.isNotEmpty)
                                        Text(d.notes,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary)),
                                    ]),
                              ),
                              Text(money(d.amount),
                                  style: const TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(width: 10),
                              IconBtn(
                                  icon: Icons.edit_rounded,
                                  color: Colors.orange.shade300,
                                  onTap: () => showDialog(
                                      context: context,
                                      builder: (_) => DiscountForm(discount: d))),
                              const SizedBox(width: 6),
                              IconBtn(
                                  icon: Icons.delete_outline_rounded,
                                  color: AppColors.danger,
                                  onTap: () => _delete(d)),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class DiscountForm extends StatefulWidget {
  final DiscountRec? discount;
  const DiscountForm({super.key, this.discount});

  @override
  State<DiscountForm> createState() => _DiscountFormState();
}

class _DiscountFormState extends State<DiscountForm> {
  Party? _party;
  late DateTime _date = widget.discount?.date ?? DateTime.now();
  late double _amount = widget.discount?.amount ?? 0;
  late String _ref = widget.discount?.reference ?? '';
  late String _notes = widget.discount?.notes ?? '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.discount != null) {
      DB.I.getParty(widget.discount!.partyId).then((p) {
        if (mounted) setState(() => _party = p);
      });
    }
  }

  Future<void> _save() async {
    if (_party == null) {
      snack(context, 'Select a customer', error: true);
      return;
    }
    if (_amount <= 0) {
      snack(context, 'Enter discount amount', error: true);
      return;
    }
    setState(() => _saving = true);
    await DB.I.saveDiscount(DiscountRec(
      id: widget.discount?.id,
      partyId: _party!.id!,
      date: _date,
      amount: _amount,
      reference: _ref.trim(),
      notes: _notes.trim(),
    ));
    if (mounted) {
      Navigator.pop(context);
      snack(context, 'Discount saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.discount == null ? 'Give Discount' : 'Edit Discount',
          style: const TextStyle(fontSize: 17)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              onTap: () async {
                final p = await pickParty(context);
                if (p != null) setState(() => _party = p);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Customer *',
                    prefixIcon: Icon(Icons.person_rounded,
                        size: 18, color: AppColors.primary)),
                child: Text(_party?.name ?? 'Tap to select',
                    style: TextStyle(
                        color: _party == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary)),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100));
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today_rounded,
                        size: 18, color: AppColors.primary)),
                child: Text(fmtDate(_date)),
              ),
            ),
            const SizedBox(height: 10),
            LField(
                label: 'Discount amount',
                number: true,
                prefix: 'Rs. ',
                initial: numText(_amount, blankZero: true),
                onChanged: (v) => _amount = toD(v)),
            const SizedBox(height: 10),
            LField(
                label: 'Reference (optional)',
                initial: _ref,
                onChanged: (v) => _ref = v),
            const SizedBox(height: 10),
            LField(
                label: 'Notes (optional)',
                initial: _notes,
                maxLines: 2,
                onChanged: (v) => _notes = v),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
