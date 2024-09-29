<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages). 
-->

This a PaginatedDataTable wrapper that allows it to support lazy loading

## Features

Allows lazy loading for PaginatedDataTable

## Getting started
Start by adding lazy_paginated_data_table to your pubspec.yaml or by running the following command
```
 flutter pub get lazy_paginated_data_table
```
## Usage


```dart
import 'package:flutter/material.dart';
import 'package:lazy_paginated_data_table/lazy_paginated_data_table.dart';

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
              searchConfig: SearchConfig(onSearch: (text) {
                print("on search called! $text ====");
              }),
              sortConfig: SortConfig(
                onSort: (asc) {
                  print("asc = ${asc}");
                },
              ),
            ),
            TableColumn<String>(
                sortConfig: SortConfig(
                  onSort: (asc) {
                    print("asc = ${asc}");
                  },
                ),
                label: Text("First name"),
                filterConfig: FilterConfig<String>(
                    items: [
                      FilterItem(label: "Azul", value: "__Azul__value"),
                      FilterItem(label: "Fellawen", value: "__Fellawen__value"),
                      FilterItem(label: "Hello", value: "__Hello__value"),
                    ],
                    onFilter: (text) {
                      print("onFilter($text) called");
                    })),
            TableColumn(
              sortConfig: SortConfig(
                onSort: (asc) {
                  print("asc = ${asc}");
                },
              ),
              label: Text("Age"),
            ),
            TableColumn(label: Text("fatherName")),
            TableColumn(label: Text("motherName")),
            TableColumn(label: Text("carBrand")),
            TableColumn(label: Text("carMake")),
          ],
          dataToRow: (data, indexInCurrentPage) {
            return DataRow(cells: [
              DataCell(Text(data.firstName)),
              DataCell(Text(data.lastName)),
              DataCell(Text("${data.age}")),
              DataCell(Text(data.fatherName)),
              DataCell(Text(data.motherName)),
              DataCell(Text(data.carBrand)),
              DataCell(Text(data.carMake)),
            ]);
          },
        ),
      ),
    );
  }

  Future<List<Person>> getData(PageInfo info) {
    var result = <Person>[];
    for (int i = 0; i < info.pageSize; i++) {
      result.add(
        Person(
          firstName: "firstName_${info.pageIndex * info.pageSize + 1}",
          lastName: "lastName_${info.pageIndex * info.pageSize + 1}",
          age: info.pageSize * info.pageIndex + i,
          carBrand: "Brand_${info.pageIndex * info.pageSize + 1}",
          carMake: "Make_${info.pageIndex * info.pageSize + 1}",
          fatherName: "Father_${info.pageIndex * info.pageSize + 1}",
          motherName: "Mother_${info.pageIndex * info.pageSize + 1}",
        ),
      );
    }
    return Future.delayed(const Duration(milliseconds: 300), () => result);
  }
}

class Person {
  final String firstName;
  final String lastName;
  final String motherName;
  final String fatherName;
  final String carBrand;
  final String carMake;
  final int age;

  Person(
      {required this.firstName,
      required this.lastName,
      required this.age,
      required this.motherName,
      required this.fatherName,
      required this.carBrand,
      required this.carMake});
  @override
  String toString() {
    return "{$age}";
  }
}

```
## Here are some screens of the example in the project
![image 1](https://github.com/Oualitsen/lazy_paginated_data_table/blob/main/images/image1.png)
![image 2](https://github.com/Oualitsen/lazy_paginated_data_table/blob/main/images/image2.png)
![image 3](https://github.com/Oualitsen/lazy_paginated_data_table/blob/main/images/image3.png)
![image 4](https://github.com/Oualitsen/lazy_paginated_data_table/blob/main/images/image4.png)


