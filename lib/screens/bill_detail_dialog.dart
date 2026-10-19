import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models.dart';
import '../services/pdf_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

Future<void> showBillDetail(BuildContext context, int billId) {
  return showDialog(
    context: context,
    builder: (_) => _BillDetailDialog(billId: billId),
  );
}

class _BillDetailDialog extends StatefulWidget {
  final int billId;
  const _BillDetailDialog({required this.billId});

  @override
  State<_BillDetailDialog> createState() => _BillDetailDialogState();
}

class _BillDetailDialogState extends State<_BillDetailDialog> {
  late final Future<Bill?> _future = DB.I.getBill(widget.billId);

  Widget _row(String k, String v, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(
            child: Text(k,
                style: TextStyle(
                    fontSize: 13,
                    color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          ),
          const SizedBox(width: 8),
          Text(v,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: color ?? AppColors.textPrimary)),
        ]),
      );

  Widget _title(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Row(children: [
          Icon(i, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(t,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: FutureBuilder<Bill?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()));
            }
            final b = snap.data;
            if (b == null) {
              return const SizedBox(
                  height: 120, child: Center(child: Text('Bill not found')));
            }
            final pending = b.remaining > 0;
            final sc = pending ? AppColors.warning : AppColors.success;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bill ${b.number}',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                          Text(fmtDate(b.date),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                        ]),
                  ),
                  SmallChip(pending ? 'Pending' : 'Paid', sc),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'PDF / Print',
                    onPressed: () => PdfService.billPdf(b),
                    icon: const Icon(Icons.picture_as_pdf_rounded,
                        color: AppColors.danger),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title(Icons.person_rounded, 'Customer'),
                        Text(b.partyName,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        if (b.categoryName.isNotEmpty)
                          Text(b.categoryName,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        if (b.items.isNotEmpty) ...[
                          _title(Icons.inventory_2_rounded, 'Items'),
                          for (int i = 0; i < b.items.length; i++)
                            AppCard(
                              padding: const EdgeInsets.all(10),
                              color: AppColors.surfaceElevated,
                              child: Row(children: [
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${i + 1}. ${b.items[i].description}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13.5)),
                                        Text(
                                            'Qty ${numText(b.items[i].qty)} × ${money(b.items[i].rate)}'
                                            '${b.items[i].discAmount > 0 ? '  (disc ${money(b.items[i].discAmount)})' : ''}',
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.textMuted)),
                                      ]),
                                ),
                                Text(money(b.items[i].amount),
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800)),
                              ]),
                            ),
                        ],
                        if (b.rooms.isNotEmpty) ...[
                          _title(Icons.home_work_rounded, 'Rooms'),
                          for (final r in b.rooms)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    _row(
                                        'Walls ${r.wallSqFt.toStringAsFixed(1)} sq.ft × ${numText(r.wallRate)}',
                                        money(r.wallTotal)),
                                    if (r.hasCeiling)
                                      _row('Ceiling', money(r.ceilingTotal)),
                                    if (r.hasRoof)
                                      _row('Roof', money(r.roofTotal)),
                                    if (r.additional > 0)
                                      _row('Additional', money(r.additional)),
                                    _row('Room total', money(r.total),
                                        bold: true, color: AppColors.primary),
                                  ]),
                            ),
                        ],
                        _title(Icons.calculate_rounded, 'Summary'),
                        if (b.additionalCharges > 0)
                          _row('Additional charges', money(b.additionalCharges)),
                        _row('Total', money(b.totalAmount), bold: true),
                        if (b.totalDiscount > 0)
                          _row('Discount', '- ${money(b.totalDiscount)}',
                              color: AppColors.success),
                        _row('Net amount', money(b.net), bold: true),
                        if (b.paidAmount > 0)
                          _row('Advance', money(b.paidAmount),
                              color: AppColors.warning),
                        const Divider(),
                        _row('Remaining', money(b.remaining),
                            bold: true,
                            color: pending
                                ? AppColors.danger
                                : AppColors.success),
                        if (b.notes.isNotEmpty) ...[
                          _title(Icons.sticky_note_2_outlined, 'Notes'),
                          Text(b.notes,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, height: 1.5)),
                        ],
                      ]),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
