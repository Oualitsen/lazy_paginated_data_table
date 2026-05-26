import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_paginated_data_table/lazy_paginated_data_table.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTable({
  GlobalKey<LazyPaginatedDataTableState<Map<String, String>>>? tableKey,
  required List<Map<String, String>> rows,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: LazyPaginatedDataTable<Map<String, String>>(
          key: tableKey,
          getData: (_) async => rows,
          getTotal: () async => rows.length,
          showCheckboxColumn: false,
          columns: [
            TableColumn(label: const Text('Name')),
            TableColumn(label: const Text('Age')),
            TableColumn(label: const Text('Email')),
          ],
          dataToRow: (Map<String, String> item, _) => DataRow(cells: [
            DataCell(Text(item['name']!)),
            DataCell(Text(item['age']!)),
            DataCell(Text(item['email']!)),
          ]),
        ),
      ),
    ),
  );
}

/// Pumps enough frames to let initState futures resolve and the StreamBuilder rebuild.
Future<void> _pumpTable(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration.zero);
  await tester.pump(Duration.zero);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders column headers and row data after loading', (tester) async {
    final rows = [
      {'name': 'Alice', 'age': '30', 'email': 'alice@example.com'},
      {'name': 'Bob', 'age': '25', 'email': 'bob@example.com'},
    ];

    await tester.pumpWidget(_buildTable(rows: rows));
    await _pumpTable(tester);

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('refreshPage reloads data', (tester) async {
    var callCount = 0;
    final rows = [
      {'name': 'Alice', 'age': '30', 'email': 'alice@example.com'},
    ];
    final key = GlobalKey<LazyPaginatedDataTableState<Map<String, String>>>();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LazyPaginatedDataTable<Map<String, String>>(
            key: key,
            getData: (_) async {
              callCount++;
              return rows;
            },
            getTotal: () async => rows.length,
            showCheckboxColumn: false,
            columns: [
              TableColumn(label: const Text('Name')),
              TableColumn(label: const Text('Age')),
              TableColumn(label: const Text('Email')),
            ],
            dataToRow: (item, _) => DataRow(cells: [
              DataCell(Text(item['name']!)),
              DataCell(Text(item['age']!)),
              DataCell(Text(item['email']!)),
            ]),
          ),
        ),
      ),
    ));
    await _pumpTable(tester);

    expect(callCount, 1);
    key.currentState!.refreshPage();
    await _pumpTable(tester);
    expect(callCount, 2);
  });
}
