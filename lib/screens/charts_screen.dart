import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../database/tables.dart';

/// 月度消费统计图表页
class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  List<({int year, int month, double total})> _trend = [];
  Map<RecordStatus, int> _statusCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = context.read<AppDatabase>();
    final trend = await db.getMonthlyTrend(6);
    final counts = await db.getStatusCounts();
    setState(() {
      _trend = trend;
      _statusCounts = counts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('消费统计')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle(theme, '月度趋势（近 6 个月）'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 240,
                    child: _buildBarChart(theme),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(theme, '当前状态分布'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: _buildPieChart(theme),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusLegend(theme),
                  if (_trend.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSectionTitle(theme, '本月明细'),
                    const SizedBox(height: 8),
                    _buildCurrentMonthSummary(theme),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  // ========== 柱状图 ==========

  Widget _buildBarChart(ThemeData theme) {
    final maxTotal = _trend.fold<double>(0, (m, t) => max(m, t.total));
    final maxY = maxTotal > 0 ? maxTotal * 1.2 : 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final item = _trend[groupIndex];
                  return BarTooltipItem(
                    '${item.year}年${item.month}月\n¥${rod.toY.toStringAsFixed(0)}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= _trend.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_trend[idx].month}月',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                  reservedSize: 22,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox.shrink();
                    return Text(
                      '¥${value.toInt()}',
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(_trend.length, (i) {
              final isCurrent = i == _trend.length - 1;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: _trend[i].total,
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withAlpha(120),
                    width: 24,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }),
          ),
          duration: const Duration(milliseconds: 300),
        ),
      ),
    );
  }

  // ========== 饼图 ==========

  static const _statusColors = {
    RecordStatus.pendingPayment: Colors.orange,
    RecordStatus.pendingInvoice: Colors.blue,
    RecordStatus.complete: Colors.green,
    RecordStatus.archived: Colors.grey,
  };

  static const _statusLabels = {
    RecordStatus.pendingPayment: '待补支付',
    RecordStatus.pendingInvoice: '待开发票',
    RecordStatus.complete: '三证齐全',
    RecordStatus.archived: '已归档',
  };

  Widget _buildPieChart(ThemeData theme) {
    final nonZero = _statusCounts.entries
        .where((e) => e.value > 0)
        .toList();

    if (nonZero.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: List.generate(nonZero.length, (i) {
          final entry = nonZero[i];
          return PieChartSectionData(
            color: _statusColors[entry.key] ?? Colors.grey,
            value: entry.value.toDouble(),
            title: '${entry.value}',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatusLegend(ThemeData theme) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: RecordStatus.values.map((status) {
        final count = _statusCounts[status] ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _statusColors[status],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${_statusLabels[status]} ($count)',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ========== 本月明细 ==========

  Widget _buildCurrentMonthSummary(ThemeData theme) {
    final current = _trend.last;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${current.year}年${current.month}月',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '¥${current.total.toStringAsFixed(2)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_statusCounts.values.fold(0, (a, b) => a + b)} 条记录',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
