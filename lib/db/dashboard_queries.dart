import '../models.dart';
import 'database_helper.dart';

class MonthStat {
  final DateTime month;
  double billed = 0;
  double received = 0; // payments + advances taken on bills
  double discount = 0; // bill discounts + payment discounts + given discounts
  int bills = 0;
  MonthStat(this.month);
}

class DebtorRow {
  final Party party;
  final double balance;
  DebtorRow(this.party, this.balance);
}

class CategoryShare {
  final String name;
  final double amount;
  final int customers;
  CategoryShare(this.name, this.amount, this.customers);
}

class RecentItem {
  final bool isBill;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final int? billId;
  final int? partyId;
  RecentItem({
    required this.isBill,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    this.billId,
    this.partyId,
  });
}

class DashboardData {
  final double receivable;
  final double totalBilled;
  final double totalReceived;
  final double totalDiscount;
  final int billCount;
  final int customers;
  final int pendingCustomers;
  final List<MonthStat> months; // oldest -> newest (last item = this month)
  final List<DebtorRow> debtors;
  final List<CategoryShare> categories;
  final List<RecentItem> recent;

  DashboardData({
    required this.receivable,
    required this.totalBilled,
    required this.totalReceived,
    required this.totalDiscount,
    required this.billCount,
    required this.customers,
    required this.pendingCustomers,
    required this.months,
    required this.debtors,
    required this.categories,
    required this.recent,
  });

  MonthStat get thisMonth => months.last;
  MonthStat get lastMonth => months[months.length - 2];

  /// Share of the (billed - discounted) amount that has been collected.
  double get collectionRate {
    final due = totalBilled - totalDiscount;
    if (due <= 0) return 0;
    return (totalReceived / due).clamp(0.0, 1.0);
  }
}

extension DashboardQueries on DB {
  Future<DashboardData> dashboardData() async {
    final d = await db;
    double n(Object? v) => ((v as num?) ?? 0).toDouble();
    String key(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

    final now = DateTime.now();
    final months =
    List.generate(6, (i) => MonthStat(DateTime(now.year, now.month - 5 + i)));
    final idx = {for (var i = 0; i < months.length; i++) key(months[i].month): i};

    double totalBilled = 0, totalReceived = 0, totalDiscount = 0;
    int billCount = 0;

    // Bills
    final billRows = await d.rawQuery('''
      SELECT substr(date,1,7) AS m, COUNT(*) AS c,
             SUM(total_amount) AS billed, SUM(total_discount) AS disc,
             SUM(paid_amount) AS adv
      FROM bills WHERE is_deleted = 0 GROUP BY m''');
    for (final r in billRows) {
      final billed = n(r['billed']), disc = n(r['disc']), adv = n(r['adv']);
      final c = (r['c'] as int?) ?? 0;
      totalBilled += billed;
      totalDiscount += disc;
      totalReceived += adv;
      billCount += c;
      final i = idx[r['m']];
      if (i != null) {
        months[i].billed += billed;
        months[i].discount += disc;
        months[i].received += adv;
        months[i].bills += c;
      }
    }

    // Payments
    final payRows = await d.rawQuery('''
      SELECT substr(date,1,7) AS m, SUM(amount) AS a, SUM(discount) AS disc
      FROM payments WHERE is_deleted = 0 GROUP BY m''');
    for (final r in payRows) {
      final a = n(r['a']), disc = n(r['disc']);
      totalReceived += a;
      totalDiscount += disc;
      final i = idx[r['m']];
      if (i != null) {
        months[i].received += a;
        months[i].discount += disc;
      }
    }

    // Discounts given separately
    final discRows = await d.rawQuery('''
      SELECT substr(date,1,7) AS m, SUM(amount) AS a
      FROM discounts WHERE is_deleted = 0 GROUP BY m''');
    for (final r in discRows) {
      final a = n(r['a']);
      totalDiscount += a;
      final i = idx[r['m']];
      if (i != null) months[i].discount += a;
    }

    // Balances per customer
    final parties = await getParties();
    final bal = await partyBalances();
    double receivable = 0;
    int pending = 0;
    final debtors = <DebtorRow>[];
    final byCat = <String, double>{};
    final catCount = <String, int>{};
    for (final p in parties) {
      final b = bal[p.id] ?? 0;
      if (b > 0.005) {
        pending++;
        receivable += b;
        debtors.add(DebtorRow(p, b));
        final cn = p.categoryName.isEmpty ? 'Uncategorized' : p.categoryName;
        byCat[cn] = (byCat[cn] ?? 0) + b;
        catCount[cn] = (catCount[cn] ?? 0) + 1;
      }
    }
    debtors.sort((a, b) => b.balance.compareTo(a.balance));
    final cats = byCat.entries
        .map((e) => CategoryShare(e.key, e.value, catCount[e.key] ?? 0))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Recent activity (latest bills + payments)
    final bills = (await getBills()).take(8);
    final pays = (await getPayments()).take(8);
    final recent = <RecentItem>[
      for (final b in bills)
        RecentItem(
          isBill: true,
          title: b.partyName,
          subtitle: 'Bill ${b.number}',
          amount: b.totalAmount,
          date: b.date,
          billId: b.id,
          partyId: b.partyId,
        ),
      for (final p in pays)
        RecentItem(
          isBill: false,
          title: p.partyName,
          subtitle: 'Payment • ${p.method}',
          amount: p.amount,
          date: p.date,
          partyId: p.partyId,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return DashboardData(
      receivable: receivable,
      totalBilled: totalBilled,
      totalReceived: totalReceived,
      totalDiscount: totalDiscount,
      billCount: billCount,
      customers: parties.length,
      pendingCustomers: pending,
      months: months,
      debtors: debtors.take(6).toList(),
      categories: cats.take(6).toList(),
      recent: recent.take(8).toList(),
    );
  }
}