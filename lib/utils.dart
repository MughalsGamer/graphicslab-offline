import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'theme.dart';

double toD(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0.0;
  return 0.0;
}

String numText(double v, {bool blankZero = false}) {
  if (blankZero && v == 0) return '';
  return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}

String money(double v) => 'Rs. ${v.toStringAsFixed(2)}';
String fmtDate(DateTime d) => DateFormat('dd-MMM-yyyy').format(d);
String fmtShort(DateTime d) => DateFormat('dd-MMM-yy').format(d);

String compact(double v) {
  if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

const _palette = [
  Color(0xFF4D8EFF),
  Color(0xFF4CAF7D),
  Color(0xFFB57BFF),
  Color(0xFFFFAA44),
  Color(0xFFFF6B6B),
  Color(0xFFEC4899),
  Color(0xFF0EA5E9),
  Color(0xFF14B8A6),
];

Color categoryColor(String name) {
  if (name.isEmpty) return AppColors.textSecondary;
  final s = name.codeUnits.fold<int>(0, (a, b) => a + b);
  return _palette[s % _palette.length];
}

void snack(BuildContext context, String msg, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(color: Colors.white)),
    backgroundColor: error ? AppColors.danger : AppColors.success,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
  ));
}

Future<bool> confirmDialog(BuildContext context, String title, String msg,
    {String okText = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: const TextStyle(fontSize: 17)),
      content: Text(msg,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: Text(okText),
        ),
      ],
    ),
  );
  return r == true;
}
