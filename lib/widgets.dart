import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor ?? AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Text field that owns its controller (initial value only), so list rows can
/// be rebuilt freely without losing the cursor.
class LField extends StatefulWidget {
  final String label;
  final String initial;
  final ValueChanged<String>? onChanged;
  final bool number;
  final String? prefix;
  final String? hint;
  final int maxLines;
  final IconData? icon;
  final String? Function(String?)? validator;
  final bool autofocus;

  const LField({
    super.key,
    required this.label,
    this.initial = '',
    this.onChanged,
    this.number = false,
    this.prefix,
    this.hint,
    this.maxLines = 1,
    this.icon,
    this.validator,
    this.autofocus = false,
  });

  @override
  State<LField> createState() => _LFieldState();
}

class _LFieldState extends State<LField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _c,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      keyboardType: widget.number
          ? const TextInputType.numberWithOptions(decimal: true)
          : (widget.maxLines > 1
              ? TextInputType.multiline
              : TextInputType.text),
      inputFormatters: widget.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
      validator: widget.validator,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixText: widget.prefix,
        prefixIcon: widget.icon == null
            ? null
            : Icon(widget.icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle),
            child: Icon(icon, size: 46, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13.5)),
          ],
        ]),
      ),
    );
  }
}

class SmallChip extends StatelessWidget {
  final String text;
  final Color color;
  const SmallChip(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );
}

class AmountBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const AmountBox(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: color.withOpacity(0.8)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: color.withOpacity(0.7),
                          fontWeight: FontWeight.w600)),
                  Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ]),
          ),
        ]),
      );
}

class IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;
  const IconBtn(
      {super.key,
      required this.icon,
      required this.color,
      required this.onTap,
      this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      );
}
