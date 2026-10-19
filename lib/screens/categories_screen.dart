import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _cats = [];
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
    final l = await DB.I.getCategories();
    if (mounted) {
      setState(() {
        _cats = l;
        _loading = false;
      });
    }
  }

  Future<void> _edit([Category? c]) async {
    String name = c?.name ?? '';
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(c == null ? 'New Category' : 'Edit Category',
            style: const TextStyle(fontSize: 17)),
        content: SizedBox(
          width: 360,
          child: Form(
            key: key,
            child: LField(
              label: 'Category name',
              hint: 'e.g. Painters, Contractors, Shops',
              initial: name,
              autofocus: true,
              icon: Icons.category_rounded,
              onChanged: (v) => name = v,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DB.I.saveCategory(Category(id: c?.id, name: name.trim()));
    } catch (_) {
      if (mounted) snack(context, 'This category already exists', error: true);
    }
  }

  Future<void> _delete(Category c) async {
    final ok = await confirmDialog(
        context, 'Delete Category', 'Delete category "${c.name}"?');
    if (!ok) return;
    final done = await DB.I.deleteCategory(c.id!);
    if (!done && mounted) {
      snack(context, 'Category has customers – move or delete them first',
          error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Category'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cats.isEmpty
              ? const EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No categories',
                  subtitle: 'Create a category to group your customers')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                  itemCount: _cats.length,
                  itemBuilder: (_, i) {
                    final c = _cats[i];
                    final col = categoryColor(c.name);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Row(children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                color: col.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.category_rounded, color: col),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  Text('${c.count} customers',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted)),
                                ]),
                          ),
                          IconBtn(
                              icon: Icons.edit_rounded,
                              color: Colors.orange.shade300,
                              onTap: () => _edit(c)),
                          const SizedBox(width: 6),
                          IconBtn(
                              icon: Icons.delete_outline_rounded,
                              color: AppColors.danger,
                              onTap: () => _delete(c)),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
