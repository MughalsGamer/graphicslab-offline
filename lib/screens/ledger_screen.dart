import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models.dart';
import '../services/pdf_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'bill_detail_dialog.dart';

class LedgerScreen extends StatefulWidget {
  final Party party;
  const LedgerScreen({super.key, required this.party});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  List<LedgerEntry> _all = [];
  bool _loading = true;
  DateTimeRange? _range;

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
    final l = await DB.I.getLedger(widget.party.id!);
    if (!mounted) return;
    setState(() {
      _all = l;
      _loading = false;
    });
  }

  DateTime get _start => DateTime(
      _range!.start.year, _range!.start.month, _range!.start.day);
  DateTime get _end => DateTime(
      _range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);

  List<LedgerEntry> get _visible => _range == null
      ? _all
      : _all
          .where((e) => !e.date.isBefore(_start) && !e.date.isAfter(_end))
          .toList();

  double get _opening {
    if (_range == null) return 0;
    LedgerEntry? last;
    for (final e in _all) {
      if (e.date.isBefore(_start)) last = e;
    }
    return last?.balance ?? 0;
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'bill':
        return AppColors.primary;
      case 'discount':
        return AppColors.warning;
      case 'advance':
        return AppColors.accent;
      case 'payment':
        return AppColors.success;
      default:
        return Colors.tealAccent;
    }
  }

  String _typeName(String t) {
    switch (t) {
      case 'bill':
        return 'Bill';
      case 'discount':
        return 'Discount';
      case 'advance':
        return 'Advance';
      case 'payment':
        return 'Payment';
      default:
        return 'Closed';
    }
  }

  void _details(LedgerEntry e) {
    if (e.type == 'closed') return;
    if (e.type == 'bill' && e.billId != null) {
      showBillDetail(context, e.billId!);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(e.description, style: const TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _kv('Date', fmtDate(e.date)),
          _kv('Type', _typeName(e.type)),
          _kv('Debit', money(e.debit)),
          _kv('Credit', money(e.credit)),
          _kv('Balance', money(e.balance)),
          if (e.note.isNotEmpty) _kv('Note', e.note),
        ]),
        actions: [
          if (e.billId != null)
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  showBillDetail(context, e.billId!);
                },
                child: const Text('View Bill')),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 64,
              child: Text('$k:',
                  style: const TextStyle(color: AppColors.textMuted))),
          Expanded(child: Text(v)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final vis = _visible;
    final opening = _opening;
    final debit = vis.fold(0.0, (s, e) => s + e.debit);
    final credit = vis.fold(0.0, (s, e) => s + e.credit);
    final closing = vis.isEmpty ? opening : vis.last.balance;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.party.name,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('Ledger – ${widget.party.categoryName}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Filter by date',
            onPressed: _pickRange,
            icon: Icon(_range == null
                ? Icons.filter_alt_outlined
                : Icons.filter_alt_rounded),
          ),
          if (_range != null)
            IconButton(
              tooltip: 'Clear filter',
              onPressed: () => setState(() => _range = null),
              icon: const Icon(Icons.clear_rounded),
            ),
          IconButton(
            tooltip: 'PDF / Print',
            onPressed: _all.isEmpty
                ? null
                : () => PdfService.ledgerPdf(
                      party: widget.party,
                      entries: vis,
                      opening: opening,
                      closing: closing,
                      start: _range?.start,
                      end: _range?.end,
                    ),
            icon: const Icon(Icons.picture_as_pdf_rounded,
                color: AppColors.danger),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              if (_range != null)
                Container(
                  width: double.infinity,
                  color: AppColors.primary.withOpacity(0.12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                      'Filtered: ${fmtDate(_range!.start)} to ${fmtDate(_range!.end)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary)),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: AmountBox(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Total Debit (paid)',
                          value: money(debit),
                          color: AppColors.danger)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: AmountBox(
                          icon: Icons.arrow_downward_rounded,
                          label: 'Total Credit (bills)',
                          value: money(credit),
                          color: AppColors.success)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: AmountBox(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Balance',
                          value: money(closing),
                          color: closing > 0.005
                              ? AppColors.warning
                              : AppColors.primary)),
                ]),
              ),
              Expanded(
                child: _all.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No ledger entries found')
                    : _table(vis, opening),
              ),
            ]),
    );
  }

  static const double _wDate = 92, _wType = 90, _wAmt = 105, _wBal = 115;
  static const double _wNote = 170;

  Widget _hCell(String t, double w, {bool right = false}) => SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(t,
              textAlign: right ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _cell(String t, double w,
          {bool right = false, Color? color, bool bold = false}) =>
      SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(t,
              textAlign: right ? TextAlign.right : TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: color ?? AppColors.textPrimary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        ),
      );

  Widget _table(List<LedgerEntry> vis, double opening) {
    return LayoutBuilder(builder: (context, c) {
      const fixed = _wDate + _wType + _wNote + _wAmt * 2 + _wBal;
      final detailsW = math.max(180.0, c.maxWidth - 24 - fixed);
      final total = fixed + detailsW;
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: total,
              child: Column(children: [
                Container(
                  color: AppColors.surfaceElevated,
                  child: Row(children: [
                    _hCell('Date', _wDate),
                    _hCell('Type', _wType),
                    _hCell('Details', detailsW),
                    _hCell('Note', _wNote),
                    _hCell('Debit', _wAmt, right: true),
                    _hCell('Credit', _wAmt, right: true),
                    _hCell('Balance', _wBal, right: true),
                  ]),
                ),
                if (_range != null)
                  Container(
                    color: AppColors.bg,
                    child: Row(children: [
                      _cell('', _wDate),
                      _cell('', _wType),
                      _cell('Opening Balance', detailsW, bold: true),
                      _cell('', _wNote),
                      _cell('', _wAmt),
                      _cell('', _wAmt),
                      _cell(money(opening), _wBal, right: true, bold: true),
                    ]),
                  ),
                Expanded(
                  child: vis.isEmpty
                      ? const Center(
                          child: Text('No entries in this period',
                              style: TextStyle(color: AppColors.textMuted)))
                      : ListView.builder(
                          itemCount: vis.length,
                          itemBuilder: (_, i) {
                            final e = vis[i];
                            final closed = e.type == 'closed';
                            final tc = _typeColor(e.type);
                            return InkWell(
                              onTap: () => _details(e),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: closed
                                      ? Colors.teal.withOpacity(0.15)
                                      : (i.isEven
                                          ? Colors.transparent
                                          : Colors.white.withOpacity(0.03)),
                                  border: const Border(
                                      bottom: BorderSide(
                                          color: AppColors.border, width: 0.5)),
                                ),
                                child: Row(children: [
                                  _cell(fmtShort(e.date), _wDate),
                                  _cell(_typeName(e.type), _wType, color: tc),
                                  _cell(e.description, detailsW,
                                      bold: closed || e.type == 'bill',
                                      color: closed ? Colors.tealAccent : null),
                                  _cell(e.note, _wNote,
                                      color: AppColors.textMuted),
                                  _cell(e.debit > 0 ? money(e.debit) : '-',
                                      _wAmt,
                                      right: true,
                                      color: e.debit > 0
                                          ? AppColors.danger
                                          : AppColors.textMuted),
                                  _cell(e.credit > 0 ? money(e.credit) : '-',
                                      _wAmt,
                                      right: true,
                                      color: e.credit > 0
                                          ? AppColors.success
                                          : AppColors.textMuted),
                                  _cell(money(e.balance), _wBal,
                                      right: true, bold: true),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
              ]),
            ),
          ),
        ),
      );
    });
  }
}
