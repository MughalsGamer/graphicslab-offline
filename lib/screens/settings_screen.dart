import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _path = '...';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final p = await DB.I.currentPath();
    if (mounted) setState(() => _path = p);
  }

  Future<void> _changeFolder() async {
    final dir = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Select folder for the database');
    if (dir == null) return;
    setState(() => _busy = true);
    try {
      await DB.I.changeDir(dir);
      await _refresh();
      if (mounted) snack(context, 'Database location changed');
    } catch (e) {
      if (mounted) snack(context, 'Could not use this folder: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backup() async {
    final dir = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Select backup folder');
    if (dir == null) return;
    setState(() => _busy = true);
    try {
      final f = await DB.I.backupTo(dir);
      if (mounted) snack(context, 'Backup saved: $f');
    } catch (e) {
      if (mounted) snack(context, 'Backup failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final ok = await confirmDialog(context, 'Use default folder',
        'Switch back to the default app folder? (Your data stays in the old folder.)',
        okText: 'Switch');
    if (!ok) return;
    await DB.I.resetDir();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.storage_rounded,
                          color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Text('Database location',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border)),
                      child: SelectableText(_path,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _changeFolder,
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: const Text('Change folder'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _backup,
                        icon: const Icon(Icons.backup_rounded, size: 18),
                        label: const Text('Backup now'),
                      ),
                      TextButton(
                          onPressed: _busy ? null : _reset,
                          child: const Text('Use default')),
                    ]),
                    const SizedBox(height: 10),
                    const Text(
                      'Changing the folder copies the current database there '
                      '(if no database exists in that folder yet). Mobile and '
                      'Windows databases are separate – there is no sync.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted, height: 1.5),
                    ),
                  ]),
            ),
            const SizedBox(height: 12),
            const AppCard(
              child: Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.textSecondary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Billing & Ledger • v1.0.0\n© Developed by Ali Haider',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
