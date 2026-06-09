import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../database/tables.dart';
import 'record_detail_screen.dart';

/// 消费记录搜索页（通过 showSearch 调用）
class RecordSearchDelegate extends SearchDelegate<ConsumptionRecord?> {
  @override
  String get searchFieldLabel => '搜索商户名、金额、备注…';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  Future<List<ConsumptionRecord>> _search(BuildContext context, String q) async {
    if (q.trim().isEmpty) return [];
    final db = context.read<AppDatabase>();
    return db.searchRecords(q.trim());
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    return FutureBuilder<List<ConsumptionRecord>>(
      future: _search(context, query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          if (query.trim().isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('输入商户名、金额或备注关键词', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('未找到匹配的记录', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return _buildSearchResult(context, record);
          },
        );
      },
    );
  }

  Widget _buildSearchResult(BuildContext context, ConsumptionRecord record) {
    final statusLabels = {
      RecordStatus.pendingPayment: '待补支付',
      RecordStatus.pendingInvoice: '待开发票',
      RecordStatus.complete: '三证齐全',
      RecordStatus.archived: '已归档',
    };
    final statusColors = {
      RecordStatus.pendingPayment: Colors.orange,
      RecordStatus.pendingInvoice: Colors.blue,
      RecordStatus.complete: Colors.green,
      RecordStatus.archived: Colors.grey,
    };

    // 高亮匹配文本
    final merchantText = _highlightMatch(context, record.merchant);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColors[record.status]?.withAlpha(30),
          child: Icon(Icons.receipt, color: statusColors[record.status]),
        ),
        title: merchantText,
        subtitle: Text(
          '${DateFormat('yyyy-MM-dd').format(record.date)}  ¥${record.amount.toStringAsFixed(2)}  ${statusLabels[record.status] ?? ''}',
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecordDetailScreen(record: record),
            ),
          );
        },
      ),
    );
  }

  Widget _highlightMatch(BuildContext context, String text) {
    final idx = text.toLowerCase().indexOf(query.toLowerCase().trim());
    if (idx < 0) return Text(text);

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyLarge,
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.trim().length),
            style: const TextStyle(
              backgroundColor: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (idx + query.trim().length < text.length)
            TextSpan(text: text.substring(idx + query.trim().length)),
        ],
      ),
    );
  }
}
