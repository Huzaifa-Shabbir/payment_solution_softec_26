import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../accounts/account_model.dart';
import '../../core/utils/state_Management.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final NumberFormat _currencyFmt;
  late AccountStore store;

  @override
  void initState() {
    super.initState();
    _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    store = AccountStoreProvider.of(context);
  }

  AnalyticsData _compute(List<Account> accounts) {
    final now = DateTime.now();
    double totalAmount = 0.0;
    double totalPaid = 0.0;
    double totalPending = 0.0;
    double totalOverdue = 0.0;

    final Map<String, double> pendingByMonth = {};
    final Map<String, double> overdueByMonth = {};
    final Map<String, double> recoveryByMonth = {};
    final List<_Defaulter> defaulters = [];

    for (final a in accounts) {
      final total = a.amount;
      final paid = a.isPaid ? a.amount : 0.0;
      final pending = (total - paid).clamp(0.0, double.infinity);

      totalAmount += total;
      totalPaid += paid;
      totalPending += pending;

      final monthKey = '${a.dueDate.year}-${a.dueDate.month.toString().padLeft(2, '0')}';

      if (a.dueDate.isBefore(now) && pending > 0) {
        totalOverdue += pending;
        overdueByMonth[monthKey] = (overdueByMonth[monthKey] ?? 0.0) + pending;
      } else if (pending > 0) {
        pendingByMonth[monthKey] = (pendingByMonth[monthKey] ?? 0.0) + pending;
      }

      if (paid > 0) {
        recoveryByMonth[monthKey] = (recoveryByMonth[monthKey] ?? 0.0) + paid;
      }

      final overdueDays = a.dueDate.isBefore(now) ? now.difference(a.dueDate).inDays : 0;
      final overdueAmount = (a.dueDate.isBefore(now) && pending > 0) ? pending : 0.0;
      if (overdueAmount > 0) {
        defaulters.add(_Defaulter(name: a.name, overdueAmount: overdueAmount, daysOverdue: overdueDays, account: a));
      }
    }

    final recoveryRate = totalAmount > 0 ? (totalPaid / totalAmount) * 100.0 : 0.0;

    final months = _lastNMonths(6);
    final pendingSeries = months.map((m) => pendingByMonth[m] ?? 0.0).toList();
    final overdueSeries = months.map((m) => overdueByMonth[m] ?? 0.0).toList();
    final recoverySeries = months.map((m) => recoveryByMonth[m] ?? 0.0).toList();

    defaulters.sort((a, b) => b.overdueAmount.compareTo(a.overdueAmount));

    return AnalyticsData(
      totalPending: totalPending,
      totalOverdue: totalOverdue,
      recoveryRate: recoveryRate,
      months: months,
      pendingSeries: pendingSeries,
      overdueSeries: overdueSeries,
      recoverySeries: recoverySeries,
      topDefaulters: defaulters,
      totalAmount: totalAmount,
      totalPaid: totalPaid,
    );
  }

  static List<String> _lastNMonths(int n) {
    final now = DateTime.now();
    final months = <String>[];
    for (int i = n - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      months.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
    return months;
  }

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-');
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 1;
    return DateFormat.MMM().format(DateTime(y, m));
  }

  String _shortAmount(double v) {
    if (v == 0) return '';
    if (v.abs() >= 1000) return NumberFormat.compactCurrency(symbol: '\$').format(v);
    return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(v);
  }

  // ------------- Section 1: Summary Cards
  Widget _summaryCards(BuildContext context, AnalyticsData data) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget _card({
      required Color bg,
      required IconData icon,
      required String title,
      required String subtitle,
      required String value,
    }) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        color: bg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.onPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.onPrimary, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: tt.titleMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: tt.bodySmall?.copyWith(color: cs.onPrimary.withOpacity(0.8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: tt.titleLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _card(
                bg: cs.primary,
                icon: Icons.schedule,
                title: 'Total Pending',
                subtitle: 'Amount due',
                value: _currencyFmt.format(data.totalPending),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _card(
                bg: cs.error,
                icon: Icons.priority_high,
                title: 'Overdue',
                subtitle: 'Past due amount',
                value: _currencyFmt.format(data.totalOverdue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          color: cs.secondary,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.onSecondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.show_chart, color: cs.onSecondary, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recovery Rate',
                        style: tt.titleMedium?.copyWith(color: cs.onSecondary, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Percent of amounts collected',
                        style: tt.bodySmall?.copyWith(color: cs.onSecondary.withOpacity(0.8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${data.recoveryRate.toStringAsFixed(1)}%',
                  style: tt.titleLarge?.copyWith(color: cs.onSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------- Section 2: Trends
  Widget _trendsSection(BuildContext context, AnalyticsData data) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final months = data.months;
    final groupWidth = 60.0;
    final chartHeight = MediaQuery.of(context).size.height * 0.25;

    double maxPendingOverdue = 0.0;
    for (int i = 0; i < months.length; i++) {
      final sum = (data.pendingSeries[i]) + (data.overdueSeries[i]);
      if (sum > maxPendingOverdue) maxPendingOverdue = sum;
    }
    final normMax = maxPendingOverdue > 0 ? maxPendingOverdue : 1.0;

    Widget _pendingOverdueChart() {
      final scrollController = ScrollController();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      });

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pending vs Overdue', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SizedBox(
                height: chartHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: scrollController,
                  child: SizedBox(
                    width: months.length * groupWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(months.length, (i) {
                        final mKey = months[i];
                        final pending = data.pendingSeries[i];
                        final overdue = data.overdueSeries[i];
                        final pendingH = (pending / normMax) * (chartHeight * 0.65);
                        final overdueH = (overdue / normMax) * (chartHeight * 0.65);
                        return SizedBox(
                          width: groupWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 28,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(child: FittedBox(child: Text(pending > 0 ? _shortAmount(pending) : '', style: tt.bodySmall))),
                                    const SizedBox(width: 2),
                                    Expanded(child: FittedBox(child: Text(overdue > 0 ? _shortAmount(overdue) : '', style: tt.bodySmall))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(width: 16, height: pendingH, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(6))),
                                  const SizedBox(width: 6),
                                  Container(width: 16, height: overdueH, decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(6))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(height: 24, child: FittedBox(child: Text(_monthLabel(mKey), style: tt.bodySmall))),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _recoveryChart() {
      final maxRate = data.recoverySeries.isEmpty ? 1.0 : data.recoverySeries.reduce((a, b) => a > b ? a : b);
      final normRateMax = maxRate > 0 ? maxRate : 1.0;
      final scrollController = ScrollController();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      });

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recovery Rate Over Time', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SizedBox(
                height: chartHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: scrollController,
                  child: SizedBox(
                    width: months.length * groupWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(months.length, (i) {
                        final rate = data.recoverySeries[i];
                        final barH = (rate / normRateMax) * (chartHeight * 0.65);
                        return SizedBox(
                          width: groupWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 28,
                                child: FittedBox(child: Text('${rate == 0 ? '' : rate.toStringAsFixed(0) + '%'}', style: tt.bodySmall)),
                              ),
                              const SizedBox(height: 8),
                              Container(width: 22, height: barH, decoration: BoxDecoration(color: cs.secondary, borderRadius: BorderRadius.circular(6))),
                              const SizedBox(height: 8),
                              SizedBox(height: 24, child: FittedBox(child: Text(_monthLabel(months[i]), style: tt.bodySmall))),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _pendingOverdueChart(),
        const SizedBox(height: 12),
        _recoveryChart(),
      ],
    );
  }

  // ------------- Section 3: Performance Metrics
  Widget _performanceMetrics(BuildContext context, AnalyticsData data) {
    final screenW = MediaQuery.of(context).size.width;
    const outerPadding = 16.0;
    const spacing = 12.0;
    final cardW = (screenW - outerPadding * 2 - spacing) / 2;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final metrics = [
      {
        'icon': Icons.group,
        'title': 'Customers',
        'value': '${store.accounts.length}',
        'color': Colors.blue,
      },
      {
        'icon': Icons.payments,
        'title': 'Total Amount',
        'value': _currencyFmt.format(data.totalAmount),
        'color': Colors.purple,
      },
      {
        'icon': Icons.check_circle,
        'title': 'Collected',
        'value': _currencyFmt.format(data.totalPaid),
        'color': Colors.green,
      },
      {
        'icon': Icons.schedule,
        'title': 'Overdue Count',
        'value': '${data.topDefaulters.length}',
        'color': Colors.red,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Performance Metrics', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics.map((m) {
            final color = m['color'] as Color;
            return SizedBox(
              width: cardW,
              child: Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Colored icon container
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(m['icon'] as IconData, color: color, size: 22),
                      ),
                      const SizedBox(height: 12),
                      // Title
                      Text(
                        m['title'] as String,
                        style: tt.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Value
                      Text(
                        m['value'] as String,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ------------- Section 4: Top Defaulters
  Widget _topDefaultersSection(BuildContext context, AnalyticsData data) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final list = data.topDefaulters;

    if (list.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Defaulters', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('No defaulters', style: tt.bodyMedium)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top Defaulters', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...list.take(8).map((d) {
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primary.withOpacity(0.12),
                    child: Text(d.name.isNotEmpty ? d.name[0].toUpperCase() : '?', style: tt.titleMedium?.copyWith(color: cs.primary)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(d.name, style: tt.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('${d.daysOverdue} days overdue', style: tt.bodySmall?.copyWith(color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _currencyFmt.format(d.overdueAmount),
                      style: tt.titleMedium?.copyWith(color: cs.error, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // ------------- Build
  @override
  Widget build(BuildContext context) {
    final accounts = store.accounts;
    final data = _compute(accounts);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryCards(context, data),
            const SizedBox(height: 18),
            _trendsSection(context, data),
            const SizedBox(height: 18),
            _performanceMetrics(context, data),
            const SizedBox(height: 18),
            _topDefaultersSection(context, data),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class AnalyticsData {
  final double totalPending;
  final double totalOverdue;
  final double recoveryRate;
  final List<String> months;
  final List<double> pendingSeries;
  final List<double> overdueSeries;
  final List<double> recoverySeries;
  final List<_Defaulter> topDefaulters;
  final double totalAmount;
  final double totalPaid;

  AnalyticsData({
    required this.totalPending,
    required this.totalOverdue,
    required this.recoveryRate,
    required this.months,
    required this.pendingSeries,
    required this.overdueSeries,
    required this.recoverySeries,
    required this.topDefaulters,
    required this.totalAmount,
    required this.totalPaid,
  });
}

class _Defaulter {
  final String name;
  final double overdueAmount;
  final int daysOverdue;
  final Account account;
  _Defaulter({required this.name, required this.overdueAmount, required this.daysOverdue, required this.account});
}