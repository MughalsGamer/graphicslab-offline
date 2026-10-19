import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models.dart';

/// Single access point for the local SQLite database.
/// Mobile and Windows each keep their own separate database file.
class DB {
  DB._();
  static final DB I = DB._();

  static const _dbName = 'billing_app.db';
  static const _prefKey = 'db_dir';

  /// Screens listen to this and reload after any write.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  void notify() => changes.value++;

  Future<Database>? _opening;
  Future<Database> get db => _opening ??= _openCurrent();

  // ───────────────────────── Location handling ─────────────────────────
  Future<String> defaultDir() async =>
      (await getApplicationDocumentsDirectory()).path;

  Future<String> currentDir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey) ?? await defaultDir();
  }

  Future<String> currentPath() async => p.join(await currentDir(), _dbName);

  Future<Database> _openCurrent() async {
    try {
      return await _open(await currentPath());
    } catch (e) {
      debugPrint('DB open failed ($e) – falling back to default folder');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
      return _open(p.join(await defaultDir(), _dbName));
    }
  }

  Future<Database> _open(String path) async {
    await Directory(p.dirname(path)).create(recursive: true);
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _close() async {
    if (_opening != null) {
      final d = await _opening!;
      await d.close();
      _opening = null;
    }
  }

  /// Switch to another folder. Existing DB is copied if the target has none.
  Future<void> changeDir(String newDir) async {
    final oldPath = await currentPath();
    final newPath = p.join(newDir, _dbName);
    if (oldPath == newPath) return;
    await _close();
    try {
      await Directory(newDir).create(recursive: true);
      if (await File(oldPath).exists() && !await File(newPath).exists()) {
        await File(oldPath).copy(newPath);
      }
      final test = await _open(newPath);
      await test.close();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newDir);
    } finally {
      notify();
    }
  }

  Future<void> resetDir() async {
    await _close();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    notify();
  }

  /// Copies the current DB file into [dir]; returns the new file path.
  Future<String> backupTo(String dir) async {
    await db; // make sure it exists
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final target = p.join(dir, 'billing_backup_$stamp.db');
    await Directory(dir).create(recursive: true);
    await File(await currentPath()).copy(target);
    return target;
  }

  // ───────────────────────── Schema ─────────────────────────
  Future<void> _onCreate(Database d, int v) async {
    final b = d.batch();
    b.execute('''CREATE TABLE categories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE)''');
    b.execute('''CREATE TABLE parties(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT DEFAULT '',
      address TEXT DEFAULT '',
      email TEXT DEFAULT '',
      category_id INTEGER,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT)''');
    b.execute('''CREATE TABLE bills(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      party_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      notes TEXT DEFAULT '',
      additional_charges REAL DEFAULT 0,
      discount_type TEXT DEFAULT 'none',
      discount_value REAL DEFAULT 0,
      total_amount REAL DEFAULT 0,
      total_discount REAL DEFAULT 0,
      paid_amount REAL DEFAULT 0,
      remaining REAL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT)''');
    b.execute('''CREATE TABLE bill_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_id INTEGER NOT NULL,
      description TEXT,
      qty REAL, rate REAL,
      disc_type TEXT, disc_value REAL,
      amount REAL)''');
    b.execute('''CREATE TABLE bill_rooms(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_id INTEGER NOT NULL,
      name TEXT,
      wall_rate REAL, additional REAL,
      has_ceiling INTEGER, has_roof INTEGER)''');
    b.execute('''CREATE TABLE room_walls(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_id INTEGER NOT NULL,
      description TEXT,
      width REAL, height REAL, qty REAL, sqft REAL)''');
    b.execute('''CREATE TABLE room_extras(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_id INTEGER NOT NULL,
      kind TEXT NOT NULL,
      description TEXT,
      length REAL, width REAL, qty REAL, rate REAL, total REAL)''');
    b.execute('''CREATE TABLE payments(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      party_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      amount REAL DEFAULT 0,
      discount REAL DEFAULT 0,
      method TEXT, reference TEXT, notes TEXT,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT)''');
    b.execute('''CREATE TABLE discounts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      party_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      amount REAL DEFAULT 0,
      reference TEXT, notes TEXT,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT)''');
    b.execute('CREATE INDEX idx_bills_party ON bills(party_id)');
    b.execute('CREATE INDEX idx_pay_party ON payments(party_id)');
    b.execute('CREATE INDEX idx_disc_party ON discounts(party_id)');
    b.execute('CREATE INDEX idx_items_bill ON bill_items(bill_id)');
    b.execute('CREATE INDEX idx_rooms_bill ON bill_rooms(bill_id)');
    b.insert('categories', {'name': 'General'});
    await b.commit(noResult: true);
  }

  String _now() => DateTime.now().toIso8601String();

  // ───────────────────────── Categories ─────────────────────────
  Future<List<Category>> getCategories() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT c.*, (SELECT COUNT(*) FROM parties p
                   WHERE p.category_id = c.id AND p.is_deleted = 0) AS cnt
      FROM categories c ORDER BY c.name COLLATE NOCASE''');
    return rows.map(Category.fromMap).toList();
  }

  Future<void> saveCategory(Category c) async {
    final d = await db;
    if (c.id == null) {
      await d.insert('categories', {'name': c.name});
    } else {
      await d.update('categories', {'name': c.name},
          where: 'id = ?', whereArgs: [c.id]);
    }
    notify();
  }

  /// Returns false if the category still has customers.
  Future<bool> deleteCategory(int id) async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT COUNT(*) AS c FROM parties WHERE category_id = ? AND is_deleted = 0',
        [id]);
    if (((r.first['c'] as int?) ?? 0) > 0) return false;
    await d.delete('categories', where: 'id = ?', whereArgs: [id]);
    notify();
    return true;
  }

  // ───────────────────────── Parties (customers) ─────────────────────────
  Future<List<Party>> getParties({int? categoryId}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT p.*, c.name AS category_name FROM parties p
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE p.is_deleted = 0 ${categoryId != null ? 'AND p.category_id = ?' : ''}
      ORDER BY p.name COLLATE NOCASE''',
        categoryId != null ? <Object?>[categoryId] : <Object?>[]);
    return rows.map(Party.fromMap).toList();
  }

  Future<Party?> getParty(int id) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT p.*, c.name AS category_name FROM parties p
      LEFT JOIN categories c ON c.id = p.category_id WHERE p.id = ?''', [id]);
    return rows.isEmpty ? null : Party.fromMap(rows.first);
  }

  Future<int> saveParty(Party party) async {
    final d = await db;
    int id;
    if (party.id == null) {
      id = await d.insert('parties', {...party.toMap(), 'created_at': _now()});
    } else {
      id = party.id!;
      await d.update('parties', party.toMap(),
          where: 'id = ?', whereArgs: [id]);
    }
    notify();
    return id;
  }

  Future<void> deleteParty(int id) async {
    final d = await db;
    await d.transaction((t) async {
      for (final tbl in ['bills', 'payments', 'discounts']) {
        await t.update(tbl, {'is_deleted': 1},
            where: 'party_id = ?', whereArgs: [id]);
      }
      await t.update('parties', {'is_deleted': 1},
          where: 'id = ?', whereArgs: [id]);
    });
    notify();
  }

  /// partyId -> outstanding balance (bills - discounts - advances - payments)
  Future<Map<int, double>> partyBalances() async {
    final d = await db;
    final m = <int, double>{};
    void add(List<Map<String, Object?>> rows, double sign) {
      for (final r in rows) {
        final id = r['pid'] as int;
        final v = ((r['v'] as num?) ?? 0).toDouble();
        m[id] = (m[id] ?? 0) + sign * v;
      }
    }

    add(
        await d.rawQuery(
            'SELECT party_id AS pid, SUM(total_amount - total_discount - paid_amount) AS v FROM bills WHERE is_deleted = 0 GROUP BY party_id'),
        1);
    add(
        await d.rawQuery(
            'SELECT party_id AS pid, SUM(amount + discount) AS v FROM payments WHERE is_deleted = 0 GROUP BY party_id'),
        -1);
    add(
        await d.rawQuery(
            'SELECT party_id AS pid, SUM(amount) AS v FROM discounts WHERE is_deleted = 0 GROUP BY party_id'),
        -1);
    return m;
  }

  // ───────────────────────── Bills ─────────────────────────
  static const _billSelect = '''
      SELECT b.*, p.name AS party_name, p.category_id AS category_id,
             c.name AS category_name
      FROM bills b
      JOIN parties p ON p.id = b.party_id
      LEFT JOIN categories c ON c.id = p.category_id''';

  Future<List<Bill>> getBills() async {
    final d = await db;
    final rows = await d.rawQuery(
        '$_billSelect WHERE b.is_deleted = 0 ORDER BY b.date DESC, b.id DESC');
    return rows.map(Bill.fromMap).toList();
  }

  Future<Bill?> getBill(int id) async {
    final d = await db;
    final rows = await d.rawQuery('$_billSelect WHERE b.id = ?', [id]);
    if (rows.isEmpty) return null;
    final bill = Bill.fromMap(rows.first);

    final items = await d.query('bill_items',
        where: 'bill_id = ?', whereArgs: [id], orderBy: 'id');
    bill.items = items.map(BillItem.fromMap).toList();

    final rooms = await d.query('bill_rooms',
        where: 'bill_id = ?', whereArgs: [id], orderBy: 'id');
    for (final r in rooms) {
      final room = Room.fromMap(r);
      final rid = r['id'] as int;
      final walls = await d.query('room_walls',
          where: 'room_id = ?', whereArgs: [rid], orderBy: 'id');
      room.walls.addAll(walls.map(Wall.fromMap));
      final extras = await d.query('room_extras',
          where: 'room_id = ?', whereArgs: [rid], orderBy: 'id');
      for (final e in extras) {
        final x = Extra.fromMap(e);
        if (e['kind'] == 'roof') {
          room.roofs.add(x);
        } else {
          room.ceilings.add(x);
        }
      }
      bill.rooms.add(room);
    }
    return bill;
  }

  Future<int> saveBill(Bill b) async {
    final d = await db;
    late int id;
    await d.transaction((t) async {
      if (b.id == null) {
        id = await t.insert('bills', {...b.toMap(), 'created_at': _now()});
      } else {
        id = b.id!;
        await t.update('bills', b.toMap(), where: 'id = ?', whereArgs: [id]);
        await t.delete('bill_items', where: 'bill_id = ?', whereArgs: [id]);
        final old = await t.query('bill_rooms',
            columns: ['id'], where: 'bill_id = ?', whereArgs: [id]);
        for (final r in old) {
          await t.delete('room_walls',
              where: 'room_id = ?', whereArgs: [r['id']]);
          await t.delete('room_extras',
              where: 'room_id = ?', whereArgs: [r['id']]);
        }
        await t.delete('bill_rooms', where: 'bill_id = ?', whereArgs: [id]);
      }
      for (final it in b.items) {
        await t.insert('bill_items', it.toMap(id));
      }
      for (final room in b.rooms) {
        final rid = await t.insert('bill_rooms', room.toMap(id));
        for (final w in room.walls) {
          await t.insert('room_walls', w.toMap(rid));
        }
        if (room.hasCeiling) {
          for (final e in room.ceilings) {
            await t.insert('room_extras', e.toMap(rid, 'ceiling'));
          }
        }
        if (room.hasRoof) {
          for (final e in room.roofs) {
            await t.insert('room_extras', e.toMap(rid, 'roof'));
          }
        }
      }
    });
    notify();
    return id;
  }

  Future<void> deleteBill(int id) async {
    final d = await db;
    await d.update('bills', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    notify();
  }

  // ───────────────────────── Payments ─────────────────────────
  Future<List<Payment>> getPayments() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT pay.*, p.name AS party_name FROM payments pay
      JOIN parties p ON p.id = pay.party_id
      WHERE pay.is_deleted = 0 ORDER BY pay.date DESC, pay.id DESC''');
    return rows.map(Payment.fromMap).toList();
  }

  Future<void> savePayment(Payment x) async {
    final d = await db;
    if (x.id == null) {
      await d.insert('payments', {...x.toMap(), 'created_at': _now()});
    } else {
      await d.update('payments', x.toMap(), where: 'id = ?', whereArgs: [x.id]);
    }
    notify();
  }

  Future<void> deletePayment(int id) async {
    final d = await db;
    await d.update('payments', {'is_deleted': 1},
        where: 'id = ?', whereArgs: [id]);
    notify();
  }

  // ───────────────────────── Discounts ─────────────────────────
  Future<List<DiscountRec>> getDiscounts() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT x.*, p.name AS party_name FROM discounts x
      JOIN parties p ON p.id = x.party_id
      WHERE x.is_deleted = 0 ORDER BY x.date DESC, x.id DESC''');
    return rows.map(DiscountRec.fromMap).toList();
  }

  Future<void> saveDiscount(DiscountRec x) async {
    final d = await db;
    if (x.id == null) {
      await d.insert('discounts', {...x.toMap(), 'created_at': _now()});
    } else {
      await d.update('discounts', x.toMap(), where: 'id = ?', whereArgs: [x.id]);
    }
    notify();
  }

  Future<void> deleteDiscount(int id) async {
    final d = await db;
    await d.update('discounts', {'is_deleted': 1},
        where: 'id = ?', whereArgs: [id]);
    notify();
  }

  // ───────────────────────── Ledger ─────────────────────────
  /// Bill  -> credit (total before discount)
  /// Bill discount / advance / payments / payment discount / discounts -> debit
  Future<List<LedgerEntry>> getLedger(int partyId) async {
    final d = await db;
    final bills = await d.query('bills',
        where: 'party_id = ? AND is_deleted = 0', whereArgs: [partyId]);
    final pays = await d.query('payments',
        where: 'party_id = ? AND is_deleted = 0', whereArgs: [partyId]);
    final discs = await d.query('discounts',
        where: 'party_id = ? AND is_deleted = 0', whereArgs: [partyId]);

    final raw = <Map<String, Object?>>[];
    var seq = 0;
    void add(DateTime date, String desc, String type, double debit,
        double credit, String note,
        {int? billId, int? paymentId, int? discountId}) {
      raw.add({
        'date': date,
        'desc': desc,
        'type': type,
        'debit': debit,
        'credit': credit,
        'note': note,
        'billId': billId,
        'paymentId': paymentId,
        'discountId': discountId,
        'seq': seq++,
      });
    }

    double num0(Object? v) => ((v as num?) ?? 0).toDouble();

    for (final b in bills) {
      final id = b['id'] as int;
      final date = DateTime.parse(b['date'] as String);
      final no = '#${id.toString().padLeft(4, '0')}';
      add(date, 'Udhaar Bill $no', 'bill', 0, num0(b['total_amount']),
          (b['notes'] as String?) ?? '',
          billId: id);
      if (num0(b['total_discount']) > 0) {
        add(date, 'Discount on Bill $no', 'discount', num0(b['total_discount']),
            0, '',
            billId: id);
      }
      if (num0(b['paid_amount']) > 0) {
        add(date, 'Advance on Bill $no', 'advance', num0(b['paid_amount']), 0,
            'Advance payment',
            billId: id);
      }
    }
    for (final x in pays) {
      final id = x['id'] as int;
      final date = DateTime.parse(x['date'] as String);
      final ref = (x['reference'] as String?) ?? '';
      final nt = (x['notes'] as String?) ?? '';
      final note = [
        (x['method'] as String?) ?? '',
        if (ref.isNotEmpty) '#$ref',
        if (nt.isNotEmpty) '- $nt'
      ].where((s) => s.isNotEmpty).join(' ');
      if (num0(x['amount']) > 0) {
        add(date, 'Payment Received', 'payment', num0(x['amount']), 0, note,
            paymentId: id);
      }
      if (num0(x['discount']) > 0) {
        add(date, 'Discount with Payment', 'discount', num0(x['discount']), 0,
            'Discount during payment',
            paymentId: id);
      }
    }
    for (final x in discs) {
      final id = x['id'] as int;
      final ref = (x['reference'] as String?) ?? '';
      final nt = (x['notes'] as String?) ?? '';
      add(DateTime.parse(x['date'] as String), 'Discount Given', 'discount',
          num0(x['amount']), 0, [if (ref.isNotEmpty) 'Ref: $ref', nt].join(' ').trim(),
          discountId: id);
    }

    raw.sort((a, b) {
      final c = (a['date'] as DateTime).compareTo(b['date'] as DateTime);
      return c != 0 ? c : (a['seq'] as int).compareTo(b['seq'] as int);
    });

    final out = <LedgerEntry>[];
    double bal = 0;
    bool wasZero = true;
    for (final e in raw) {
      bal += (e['credit'] as double) - (e['debit'] as double);
      out.add(LedgerEntry(
        date: e['date'] as DateTime,
        description: e['desc'] as String,
        type: e['type'] as String,
        debit: e['debit'] as double,
        credit: e['credit'] as double,
        balance: bal,
        note: e['note'] as String,
        billId: e['billId'] as int?,
        paymentId: e['paymentId'] as int?,
        discountId: e['discountId'] as int?,
      ));
      final isZero = bal.abs() < 0.005;
      if (isZero && !wasZero) {
        out.add(LedgerEntry(
          date: e['date'] as DateTime,
          description: 'LEDGER CLOSED',
          type: 'closed',
          debit: 0,
          credit: 0,
          balance: 0,
          note: 'Balance cleared',
        ));
      }
      wasZero = isZero;
    }
    return out;
  }
}
