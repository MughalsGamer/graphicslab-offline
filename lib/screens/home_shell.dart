// import 'package:flutter/material.dart';
// import '../theme.dart';
// import 'bill_list_screen.dart';
// import 'categories_screen.dart';
// import 'discounts_screen.dart';
// import 'parties_screen.dart';
// import 'payments_screen.dart';
// import 'settings_screen.dart';
//
// class HomeShell extends StatefulWidget {
//   const HomeShell({super.key});
//
//   @override
//   State<HomeShell> createState() => _HomeShellState();
// }
//
// class _HomeShellState extends State<HomeShell> {
//   int _i = 0;
//
//   static const _wideDest = <(IconData, String)>[
//     (Icons.receipt_long_rounded, 'Bills'),
//     (Icons.people_alt_rounded, 'Customers'),
//     (Icons.payments_rounded, 'Payments'),
//     (Icons.local_offer_rounded, 'Discounts'),
//     (Icons.category_rounded, 'Categories'),
//     (Icons.settings_rounded, 'Settings'),
//   ];
//
//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(builder: (context, c) {
//       final wide = c.maxWidth >= 800;
//       if (wide) {
//         final extended = c.maxWidth >= 1100;
//         final idx = _i.clamp(0, 5);
//         return Scaffold(
//           body: Row(children: [
//             NavigationRail(
//               selectedIndex: idx,
//               extended: extended,
//               labelType:
//                   extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
//               onDestinationSelected: (v) => setState(() => _i = v),
//               leading: Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 child: Row(mainAxisSize: MainAxisSize.min, children: [
//                   const Icon(Icons.account_balance_wallet_rounded,
//                       color: AppColors.primary, size: 28),
//                   if (extended) ...[
//                     const SizedBox(width: 10),
//                     const Text('Billing',
//                         style: TextStyle(
//                             fontSize: 18, fontWeight: FontWeight.w800)),
//                   ],
//                 ]),
//               ),
//               destinations: [
//                 for (final d in _wideDest)
//                   NavigationRailDestination(
//                       icon: Icon(d.$1), label: Text(d.$2)),
//               ],
//             ),
//             const VerticalDivider(width: 1),
//             Expanded(
//               child: IndexedStack(index: idx, children: const [
//                 BillListScreen(),
//                 PartiesScreen(),
//                 PaymentsScreen(),
//                 DiscountsScreen(),
//                 CategoriesScreen(),
//                 SettingsScreen(),
//               ]),
//             ),
//           ]),
//         );
//       }
//       final idx = _i.clamp(0, 4);
//       return Scaffold(
//         body: IndexedStack(index: idx, children: const [
//           BillListScreen(),
//           PartiesScreen(),
//           PaymentsScreen(),
//           DiscountsScreen(),
//           _MoreScreen(),
//         ]),
//         bottomNavigationBar: NavigationBar(
//           selectedIndex: idx,
//           onDestinationSelected: (v) => setState(() => _i = v),
//           destinations: const [
//             NavigationDestination(
//                 icon: Icon(Icons.receipt_long_rounded), label: 'Bills'),
//             NavigationDestination(
//                 icon: Icon(Icons.people_alt_rounded), label: 'Customers'),
//             NavigationDestination(
//                 icon: Icon(Icons.payments_rounded), label: 'Payments'),
//             NavigationDestination(
//                 icon: Icon(Icons.local_offer_rounded), label: 'Discounts'),
//             NavigationDestination(
//                 icon: Icon(Icons.more_horiz_rounded), label: 'More'),
//           ],
//         ),
//       );
//     });
//   }
// }
//
// class _MoreScreen extends StatelessWidget {
//   const _MoreScreen();
//
//   @override
//   Widget build(BuildContext context) {
//     Widget tile(IconData i, String t, String s, Widget page, Color c) {
//       return Card(
//         color: AppColors.surface,
//         margin: const EdgeInsets.only(bottom: 10),
//         shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//             side: const BorderSide(color: AppColors.border)),
//         child: ListTile(
//           leading: Icon(i, color: c),
//           title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
//           subtitle: Text(s,
//               style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
//           trailing: const Icon(Icons.chevron_right_rounded),
//           onTap: () => Navigator.push(
//               context, MaterialPageRoute(builder: (_) => page)),
//         ),
//       );
//     }
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('More')),
//       body: ListView(padding: const EdgeInsets.all(14), children: [
//         tile(Icons.category_rounded, 'Categories',
//             'Create / edit customer categories', const CategoriesScreen(),
//             AppColors.accent),
//         tile(Icons.settings_rounded, 'Settings',
//             'Database location & backup', const SettingsScreen(),
//             AppColors.primary),
//       ]),
//     );
//   }
// }


import 'package:flutter/material.dart';
import '../theme.dart';
import 'bill_list_screen.dart';
import 'categories_screen.dart';
import 'dashboard_screen.dart';
import 'discounts_screen.dart';
import 'parties_screen.dart';
import 'payments_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;

  static const _wideDest = <(IconData, String)>[
    (Icons.dashboard_rounded, 'Dashboard'),
    (Icons.receipt_long_rounded, 'Bills'),
    (Icons.people_alt_rounded, 'Customers'),
    (Icons.payments_rounded, 'Payments'),
    (Icons.local_offer_rounded, 'Discounts'),
    (Icons.category_rounded, 'Categories'),
    (Icons.settings_rounded, 'Settings'),
  ];

  /// Indices 0..3 (Dashboard, Bills, Customers, Payments) are the same on
  /// mobile and desktop, so the dashboard can jump to them safely.
  void _go(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 800;
      if (wide) {
        final extended = c.maxWidth >= 1100;
        final idx = _i.clamp(0, 6);
        return Scaffold(
          body: Row(children: [
            NavigationRail(
              selectedIndex: idx,
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              onDestinationSelected: (v) => setState(() => _i = v),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.primary, size: 28),
                  if (extended) ...[
                    const SizedBox(width: 10),
                    const Text('Billing',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ]),
              ),
              destinations: [
                for (final d in _wideDest)
                  NavigationRailDestination(
                      icon: Icon(d.$1), label: Text(d.$2)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(index: idx, children: [
                DashboardScreen(onGoTo: _go),
                const BillListScreen(),
                const PartiesScreen(),
                const PaymentsScreen(),
                const DiscountsScreen(),
                const CategoriesScreen(),
                const SettingsScreen(),
              ]),
            ),
          ]),
        );
      }
      final idx = _i.clamp(0, 4);
      return Scaffold(
        body: IndexedStack(index: idx, children: [
          DashboardScreen(onGoTo: _go),
          const BillListScreen(),
          const PartiesScreen(),
          const PaymentsScreen(),
          const _MoreScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_rounded), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_rounded), label: 'Bills'),
            NavigationDestination(
                icon: Icon(Icons.people_alt_rounded), label: 'Customers'),
            NavigationDestination(
                icon: Icon(Icons.payments_rounded), label: 'Payments'),
            NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded), label: 'More'),
          ],
        ),
      );
    });
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData i, String t, String s, Widget page, Color c) {
      return Card(
        color: AppColors.surface,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border)),
        child: ListTile(
          leading: Icon(i, color: c),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(s,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => page)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        tile(Icons.local_offer_rounded, 'Discounts',
            'Discounts given to customers', const DiscountsScreen(),
            AppColors.warning),
        tile(Icons.category_rounded, 'Categories',
            'Create / edit customer categories', const CategoriesScreen(),
            AppColors.accent),
        tile(Icons.settings_rounded, 'Settings',
            'Database location & backup', const SettingsScreen(),
            AppColors.primary),
      ]),
    );
  }
}
