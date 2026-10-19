import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/dashboard_queries.dart';
import '../db/database_helper.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'add_edit_bill_screen.dart';
import 'bill_detail_dialog.dart';
import 'discounts_screen.dart';
import 'ledger_screen.dart';
import 'party_dialogs.dart';
import 'payments_screen.dart';

/// [onGoTo] switches the home shell tab: 1 = Bills, 2 = Customers, 3 = Payments.
class DashboardScreen extends StatefulWidget {
  final void Function(int index)? onGoTo;
  const DashboardScreen({super.key, this.onGoTo});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _d;
  bool _loading = true;
  Object? _err;

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
    try {
      final d = await DB.I.dashboardData();
      if (!mounted) return;
      setState(() {
        _d = d;
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e;
      });
    }
  }

  void _go(int i) => widget.onGoTo?.call(i);

  Future<void> _openLedgerFor(int partyId) async {
    final p = await DB.I.getParty(partyId);
    if (p == null || !mounted) return;
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => LedgerScreen(party: p)));
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : d == null
          ? EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load dashboard',
          subtitle: '$_err')
          : RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: _content(d, w - 28),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ───────────────────────── Layout ─────────────────────────
  Widget _content(DashboardData d, double w) {
    final twoCol = w >= 960;
    final left = [
      _chartPanel(d),
      const SizedBox(height: 14),
      _recentPanel(d),
    ];
    final right = [
      _categoryPanel(d),
      const SizedBox(height: 14),
      _debtorsPanel(d),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 12),
        child: Text(DateFormat('EEEE, dd MMM yyyy').format(DateTime.now()),
            style:
            const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
      ),
      _hero(d, w),
      const SizedBox(height: 14),
      _kpis(d, w),
      const SizedBox(height: 14),
      _quickActions(),
      const SizedBox(height: 14),
      if (twoCol)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: Column(children: left)),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: Column(children: right)),
        ])
      else ...[...left, const SizedBox(height: 14), ...right],
    ]);
  }

  // ───────────────────────── Hero: receivable ─────────────────────────
  Widget _hero(DashboardData d, double w) {
    final m = d.thisMonth;
    final rate = d.collectionRate;

    final main = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Total receivable',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(money(d.receivable),
            style: const TextStyle(
                fontSize: 34,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
      ),
      const SizedBox(height: 6),
      Text(
          d.pendingCustomers == 0
              ? 'No pending balances'
              : '${d.pendingCustomers} of ${d.customers} customers have a pending balance',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
      const SizedBox(height: 16),
      Row(children: [
        Text('Collected ${(rate * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success)),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 7,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
        ),
      ]),
    ]);

    final month = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('This month (${DateFormat('MMM').format(m.month)})',
          style:
          const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
      const SizedBox(height: 10),
      _miniStat('Billed', money(m.billed), AppColors.primary),
      _miniStat('Received', money(m.received), AppColors.success),
      _miniStat('Discounts', money(m.discount), AppColors.warning),
    ]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.16),
            AppColors.surface,
          ],
        ),
      ),
      child: w >= 700
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: main),
        const SizedBox(width: 24),
        Container(width: 1, height: 130, color: AppColors.border),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: month),
      ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        main,
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 14),
        month,
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary))),
      Text(value,
          style: const TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w700)),
    ]),
  );

  // ───────────────────────── KPI cards ─────────────────────────
  Widget _kpis(DashboardData d, double w) {
    final cols = w >= 760 ? 4 : 2;
    const gap = 10.0;
    final cw = (w - gap * (cols - 1)) / cols;
    final t = d.thisMonth, l = d.lastMonth;
    final cards = <Widget>[
      _StatCard(
        icon: Icons.receipt_long_rounded,
        label: 'Total billed',
        value: money(d.totalBilled),
        sub: '${d.billCount} bills',
        color: AppColors.primary,
        delta: _delta(t.billed, l.billed),
      ),
      _StatCard(
        icon: Icons.payments_rounded,
        label: 'Total received',
        value: money(d.totalReceived),
        sub: 'Payments + advances',
        color: AppColors.success,
        delta: _delta(t.received, l.received),
      ),
      _StatCard(
        icon: Icons.local_offer_rounded,
        label: 'Total discounts',
        value: money(d.totalDiscount),
        sub: 'Given to customers',
        color: AppColors.warning,
        delta: _delta(t.discount, l.discount, upGood: false),
      ),
      _StatCard(
        icon: Icons.people_alt_rounded,
        label: 'Customers',
        value: '${d.customers}',
        sub:
        '${d.pendingCustomers} pending • ${d.customers - d.pendingCustomers} cleared',
        color: AppColors.accent,
      ),
    ];
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [for (final c in cards) SizedBox(width: cw, child: c)],
    );
  }

  Widget? _delta(double cur, double prev, {bool upGood = true}) {
    if (prev <= 0) return null;
    final pct = (cur - prev) / prev * 100;
    final up = pct >= 0;
    final good = up == upGood;
    return SmallChip('${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}%',
        good ? AppColors.success : AppColors.danger);
  }

  // ───────────────────────── Quick actions ─────────────────────────
  Widget _quickActions() {
    return Row(children: [
      Expanded(
        child: _ActionTile(
          icon: Icons.add_card_rounded,
          label: 'New bill',
          color: AppColors.primary,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddEditBillScreen())),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ActionTile(
          icon: Icons.payments_rounded,
          label: 'Receive payment',
          color: AppColors.success,
          onTap: () => showDialog(
              context: context, builder: (_) => const PaymentForm()),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ActionTile(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Add customer',
          color: AppColors.accent,
          onTap: () => showPartyForm(context),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ActionTile(
          icon: Icons.local_offer_rounded,
          label: 'Give discount',
          color: AppColors.warning,
          onTap: () => showDialog(
              context: context, builder: (_) => const DiscountForm()),
        ),
      ),
    ]);
  }

  // ───────────────────────── Panels ─────────────────────────
  Widget _chartPanel(DashboardData d) {
    return _Panel(
      title: 'Billed vs received',
      icon: Icons.bar_chart_rounded,
      color: AppColors.primary,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: const [
        _Legend('Billed', AppColors.primary),
        SizedBox(width: 12),
        _Legend('Received', AppColors.success),
      ]),
      child: _MonthlyChart(months: d.months),
    );
  }

  Widget _categoryPanel(DashboardData d) {
    final max = d.categories.isEmpty ? 0.0 : d.categories.first.amount;
    return _Panel(
      title: 'Receivable by category',
      icon: Icons.category_rounded,
      color: AppColors.accent,
      child: d.categories.isEmpty
          ? const _EmptyNote('No pending balances in any category')
          : Column(children: [
        for (final c in d.categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Text(c.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Text(money(c.amount),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: max <= 0 ? 0 : c.amount / max,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor:
                  AlwaysStoppedAnimation(categoryColor(c.name)),
                ),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    '${c.customers} customer${c.customers == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _debtorsPanel(DashboardData d) {
    return _Panel(
      title: 'Highest balances',
      icon: Icons.hourglass_top_rounded,
      color: AppColors.danger,
      trailing: TextButton(
          onPressed: () => _go(2), child: const Text('All customers')),
      child: d.debtors.isEmpty
          ? const _EmptyNote('All customers are cleared')
          : Column(children: [
        for (int i = 0; i < d.debtors.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _debtorRow(d.debtors[i]),
        ],
      ]),
    );
  }

  Widget _debtorRow(DebtorRow r) {
    final p = r.party;
    final cc = categoryColor(p.categoryName);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => LedgerScreen(party: p))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [cc, cc.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  if (p.categoryName.isNotEmpty)
                    Text(p.categoryName,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted)),
                ]),
          ),
          Text(money(r.balance),
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger)),
        ]),
      ),
    );
  }

  Widget _recentPanel(DashboardData d) {
    return _Panel(
      title: 'Recent activity',
      icon: Icons.history_rounded,
      color: AppColors.success,
      trailing:
      TextButton(onPressed: () => _go(1), child: const Text('All bills')),
      child: d.recent.isEmpty
          ? const _EmptyNote('Bills and payments will show up here')
          : Column(children: [
        for (int i = 0; i < d.recent.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _recentRow(d.recent[i]),
        ],
      ]),
    );
  }

  Widget _recentRow(RecentItem r) {
    final c = r.isBill ? AppColors.primary : AppColors.success;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (r.isBill && r.billId != null) {
          showBillDetail(context, r.billId!);
        } else if (r.partyId != null) {
          _openLedgerFor(r.partyId!);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: c.withOpacity(0.14),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(
                r.isBill ? Icons.receipt_long_rounded : Icons.payments_rounded,
                size: 19,
                color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('${r.subtitle}  •  ${fmtDate(r.date)}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textMuted)),
                ]),
          ),
          Text('${r.isBill ? '' : '+ '}${money(r.amount)}',
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800, color: c)),
        ]),
      ),
    );
  }
}

// ───────────────────────── Building blocks ─────────────────────────
class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  final Widget child;
  const _Panel({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style:
                const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final Widget? delta;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const Spacer(),
          if (delta != null) delta!,
        ]),
        const SizedBox(height: 12),
        Text(label,
            style:
            const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 3),
        Text(sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 7),
          Text(label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String text;
  final Color color;
  const _Legend(this.text, this.color);

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(text,
            style:
            const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
      ]);
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary)),
    ),
  );
}

/// Grouped bars (billed / received) for the last months, no chart package needed.
class _MonthlyChart extends StatelessWidget {
  final List<MonthStat> months;
  const _MonthlyChart({required this.months});

  static const double _h = 150;

  @override
  Widget build(BuildContext context) {
    double max = 0;
    for (final m in months) {
      if (m.billed > max) max = m.billed;
      if (m.received > max) max = m.received;
    }
    if (max <= 0) {
      return const _EmptyNote('No bills or payments in the last 6 months');
    }
    return Column(children: [
      SizedBox(
        height: _h + 18,
        child: Stack(children: [
          Positioned.fill(
            bottom: 18,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                  4,
                      (_) => Divider(
                      height: 1, color: AppColors.border.withOpacity(0.6))),
            ),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final m in months)
              Expanded(
                child: Column(children: [
                  SizedBox(
                    height: _h,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _bar(m.billed, max, AppColors.primary),
                          const SizedBox(width: 4),
                          _bar(m.received, max, AppColors.success),
                        ]),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 14,
                    child: Text(DateFormat('MMM').format(m.month),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ),
                ]),
              ),
          ]),
        ]),
      ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerRight,
        child: Text('Highest bar: Rs. ${compact(max)}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
      ),
    ]);
  }

  Widget _bar(double v, double max, Color c) {
    final f = v <= 0 ? 0.0 : (v / max).clamp(0.02, 1.0);
    return Tooltip(
      message: money(v),
      child: SizedBox(
        width: 16,
        height: _h,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: f,
            child: Container(
              decoration: BoxDecoration(
                color: c,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}