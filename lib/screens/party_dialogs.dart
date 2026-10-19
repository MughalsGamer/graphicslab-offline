import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Register / edit a customer. Returns the saved [Party] (or null if cancelled).
Future<Party?> showPartyForm(BuildContext context,
    {Party? party, int? categoryId}) async {
  final cats = await DB.I.getCategories();
  if (!context.mounted) return null;
  if (cats.isEmpty) {
    snack(context, 'Create a category first (Categories screen)', error: true);
    return null;
  }
  return showDialog<Party>(
    context: context,
    builder: (_) => _PartyForm(party: party, cats: cats, categoryId: categoryId),
  );
}

class _PartyForm extends StatefulWidget {
  final Party? party;
  final List<Category> cats;
  final int? categoryId;
  const _PartyForm({this.party, required this.cats, this.categoryId});

  @override
  State<_PartyForm> createState() => _PartyFormState();
}

class _PartyFormState extends State<_PartyForm> {
  final _key = GlobalKey<FormState>();
  late String _name = widget.party?.name ?? '';
  late String _phone = widget.party?.phone ?? '';
  late String _address = widget.party?.address ?? '';
  late String _email = widget.party?.email ?? '';
  int? _catId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _catId = widget.party?.categoryId ??
        widget.categoryId ??
        (widget.cats.isNotEmpty ? widget.cats.first.id : null);
    if (!widget.cats.any((c) => c.id == _catId)) {
      _catId = widget.cats.first.id;
    }
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    final p = Party(
      id: widget.party?.id,
      name: _name.trim(),
      phone: _phone.trim(),
      address: _address.trim(),
      email: _email.trim(),
      categoryId: _catId,
    );
    final id = await DB.I.saveParty(p);
    p.id = id;
    p.categoryName = widget.cats.firstWhere((c) => c.id == _catId).name;
    if (mounted) Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.party != null;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(editing ? 'Edit Customer' : 'Register Customer',
          style: const TextStyle(fontSize: 17)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                value: _catId,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(
                    labelText: 'Category *',
                    prefixIcon: Icon(Icons.category_rounded,
                        size: 18, color: AppColors.primary)),
                items: widget.cats
                    .map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _catId = v),
              ),
              const SizedBox(height: 10),
              LField(
                label: 'Customer name *',
                initial: _name,
                icon: Icons.person_rounded,
                autofocus: !editing,
                onChanged: (v) => _name = v,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              LField(
                  label: 'Phone',
                  initial: _phone,
                  icon: Icons.phone_rounded,
                  onChanged: (v) => _phone = v),
              const SizedBox(height: 10),
              LField(
                  label: 'Address',
                  initial: _address,
                  icon: Icons.location_on_rounded,
                  onChanged: (v) => _address = v),
              const SizedBox(height: 10),
              LField(
                  label: 'Email',
                  initial: _email,
                  icon: Icons.email_rounded,
                  onChanged: (v) => _email = v),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(editing ? 'Update' : 'Register')),
      ],
    );
  }
}

/// Search & select a customer. Optionally lets the user register a new one.
Future<Party?> pickParty(BuildContext context,
    {int? categoryId, bool allowNew = true}) {
  return showDialog<Party>(
    context: context,
    builder: (_) => _PartyPicker(categoryId: categoryId, allowNew: allowNew),
  );
}

class _PartyPicker extends StatefulWidget {
  final int? categoryId;
  final bool allowNew;
  const _PartyPicker({this.categoryId, required this.allowNew});

  @override
  State<_PartyPicker> createState() => _PartyPickerState();
}

class _PartyPickerState extends State<_PartyPicker> {
  List<Party> _all = [];
  String _q = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await DB.I.getParties(categoryId: widget.categoryId);
    if (mounted) {
      setState(() {
        _all = l;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = _all
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.phone.contains(q))
        .toList();
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              const Expanded(
                  child: Text('Select Customer',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700))),
              if (widget.allowNew)
                TextButton.icon(
                  onPressed: () async {
                    final p = await showPartyForm(context,
                        categoryId: widget.categoryId);
                    if (p != null && context.mounted) Navigator.pop(context, p);
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('New'),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LField(
              label: 'Search name / phone',
              icon: Icons.search_rounded,
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No customers found',
                            style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final p = list[i];
                          final c = categoryColor(p.categoryName);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: c.withOpacity(0.2),
                              child: Text(p.name[0].toUpperCase(),
                                  style: TextStyle(
                                      color: c, fontWeight: FontWeight.w700)),
                            ),
                            title: Text(p.name,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                                [p.categoryName, p.phone]
                                    .where((s) => s.isNotEmpty)
                                    .join(' • '),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted)),
                            onTap: () => Navigator.pop(context, p),
                          );
                        },
                      ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
            ),
          ),
        ]),
      ),
    );
  }
}
