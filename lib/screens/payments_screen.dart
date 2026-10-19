import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'party_dialogs.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Payment> _all = [];
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
    final l = await DB.I.getPayments();
    if (mounted) {
      setState(() {
        _all = l;
        _loading = false;
      });
    }
  }

  Future<void> _delete(Payment p) async {
    final ok = await confirmDialog(context, 'Delete Payment',
        'Delete payment of ${money(p.amount)} from ${p.partyName}?');
    if (!ok) return;
    await DB.I.deletePayment(p.id!);
    if (mounted) snack(context, 'Payment deleted');
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = _all
        .where((p) =>
            q.isEmpty ||
            p.partyName.toLowerCase().contains(q) ||
            p.reference.toLowerCase().contains(q))
        .toList();
    final total = list.fold(0.0, (s, p) => s + p.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Payments Received')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
            context: context, builder: (_) => const PaymentForm()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Receive Payment'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Search payments...',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 170,
              child: AmountBox(
                  icon: Icons.payments_rounded,
                  label: 'Total received',
                  value: money(total),
                  color: AppColors.success),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? const EmptyState(
                      icon: Icons.payments_outlined,
                      title: 'No payments yet',
                      subtitle: 'Receive a payment from a customer')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            child: Row(children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.payments_rounded,
                                    color: AppColors.success),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.partyName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                          [
                                            fmtDate(p.date),
                                            p.method,
                                            if (p.reference.isNotEmpty)
                                              '#${p.reference}'
                                          ].join('  •  '),
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textMuted)),
                                      if (p.notes.isNotEmpty)
                                        Text(p.notes,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary)),
                                    ]),
                              ),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(money(p.amount),
                                        style: const TextStyle(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w800)),
                                    if (p.discount > 0)
                                      Text('Disc ${money(p.discount)}',
                                          style: const TextStyle(
                                              color: AppColors.warning,
                                              fontSize: 11)),
                                  ]),
                              const SizedBox(width: 10),
                              IconBtn(
                                  icon: Icons.edit_rounded,
                                  color: Colors.orange.shade300,
                                  onTap: () => showDialog(
                                      context: context,
                                      builder: (_) => PaymentForm(payment: p))),
                              const SizedBox(width: 6),
                              IconBtn(
                                  icon: Icons.delete_outline_rounded,
                                  color: AppColors.danger,
                                  onTap: () => _delete(p)),
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

class PaymentForm extends StatefulWidget {
  final Payment? payment;
  const PaymentForm({super.key, this.payment});

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  Party? _party;
  late DateTime _date = widget.payment?.date ?? DateTime.now();
  late double _amount = widget.payment?.amount ?? 0;
  late double _discount = widget.payment?.discount ?? 0;
  late String _method = widget.payment?.method ?? 'Cash';
  late String _ref = widget.payment?.reference ?? '';
  late String _notes = widget.payment?.notes ?? '';
  bool _saving = false;
  static const _methods = ['Cash', 'Bank Transfer', 'Cheque', 'Online', 'Other'];

  @override
  void initState() {
    super.initState();
    if (widget.payment != null) {
      DB.I.getParty(widget.payment!.partyId).then((p) {
        if (mounted) setState(() => _party = p);
      });
    }
  }

  Future<void> _save() async {
    if (_party == null) {
      snack(context, 'Select a customer', error: true);
      return;
    }
    if (_amount <= 0 && _discount <= 0) {
      snack(context, 'Enter an amount', error: true);
      return;
    }
    setState(() => _saving = true);
    await DB.I.savePayment(Payment(
      id: widget.payment?.id,
      partyId: _party!.id!,
      date: _date,
      amount: _amount,
      discount: _discount,
      method: _method,
      reference: _ref.trim(),
      notes: _notes.trim(),
    ));
    if (mounted) {
      Navigator.pop(context);
      snack(context, 'Payment saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.payment == null ? 'Receive Payment' : 'Edit Payment',
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
                label: 'Amount',
                number: true,
                prefix: 'Rs. ',
                initial: numText(_amount, blankZero: true),
                onChanged: (v) => _amount = toD(v)),
            const SizedBox(height: 10),
            LField(
                label: 'Discount with payment (optional)',
                number: true,
                prefix: 'Rs. ',
                initial: numText(_discount, blankZero: true),
                onChanged: (v) => _discount = toD(v)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _method,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: _methods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _method = v!),
            ),
            const SizedBox(height: 10),
            LField(
                label: 'Reference # (optional)',
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
