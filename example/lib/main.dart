import 'package:flutter/material.dart';
import 'lazy_table.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Table"),
      ),
      body: SingleChildScrollView(
        child: LazyPaginatedDataTable<Person>(
          selectedColumnsKey: "myTable",
          getData: getData,
          getTotal: () => Future.value(115),
          availableRowsPerPage: const [5, 10, 15, 20],
          selectableColumns: true,
          showCheckboxColumn: true,
          columns: [
            TableColumn(
              key: "Last name",
              label: Text("Last name"),
            ),
            TableColumn(
              label: Text("First name"),
            ),
            TableColumn(label: Text("Age")),
          ],
          dataToRow: (data, indexInCurrentPage) {
            return DataRow(cells: [
              DataCell(Text(data.firstName)),
              DataCell(Text(data.lastName)),
              DataCell(Text("${data.age}")),
            ]);
          },
        ),
      ),
    );
  }

  Future<List<Person>> getData(PageInfo info) {
    var result = <Person>[];
    for (int i = 0; i < info.pageSize; i++) {
      result.add(Person(
          firstName: "firstName_${info.pageIndex * info.pageSize + 1}",
          lastName: "lastName_${info.pageIndex * info.pageSize + 1}",
          age: info.pageSize * info.pageIndex + i));
    }
    return Future.delayed(const Duration(milliseconds: 300), () => result);
  }
}

class Person {
  final String firstName;
  final String lastName;
  final int age;

  Person({
    required this.firstName,
    required this.lastName,
    required this.age,
  });
  @override
  String toString() {
    return "{$age}";
  }
}
