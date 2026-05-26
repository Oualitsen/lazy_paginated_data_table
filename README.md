# lazy_paginated_data_table

A Flutter package that wraps `PaginatedDataTable` with lazy loading, search, filter, sort, column visibility, and row selection — with **zero external dependencies**.

## Features

- **Lazy loading** — `getData` and `getTotal` callbacks are called per page; the table never loads more than one page at a time
- **Search** — per-column text search with debounce
- **Filter** — per-column dropdown filter with multi-select and debounce
- **Sort** — per-column sort with ascending/descending indicator; only one column can be sorted at a time
- **Selectable columns** — users can show/hide columns; selection is persisted via `SharedPreferences`
- **Row selection** — checkbox selection with `onSelectedIndexesChanged` / `onSelectedDataChanged` callbacks
- **Empty state** — optional `emptyBuilder` shown when `getData` returns an empty list
- **Loading state** — optional `initialLoading` and `onPageLoading` builders
- **Error state** — optional `errorBuilder` with a built-in retry button fallback
- **Dart 3 / Flutter 3** ready

## Getting started

```bash
flutter pub add lazy_paginated_data_table
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:lazy_paginated_data_table/lazy_paginated_data_table.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: LazyPaginatedDataTable<Person>(
          getData: (PageInfo info) => fetchPersons(info.pageIndex, info.pageSize),
          getTotal: () => fetchPersonCount(),
          availableRowsPerPage: const [10, 20, 50],
          columns: [
            TableColumn(
              key: "name",
              label: const Text("Name"),
              searchConfig: SearchConfig(
                onSearch: (text) => debugPrint("search: $text"),
              ),
              sortConfig: SortConfig(
                onSort: (asc) => debugPrint("sort asc=$asc"),
              ),
            ),
            TableColumn<String>(
              label: const Text("Country"),
              filterConfig: FilterConfig<String>(
                items: [
                  FilterItem(label: "Algeria", value: "dz"),
                  FilterItem(label: "France", value: "fr"),
                  FilterItem(label: "USA", value: "us"),
                ],
                onFilter: (selected) => debugPrint("filter: $selected"),
              ),
            ),
            TableColumn(
              label: const Text("Age"),
              sortConfig: SortConfig(onSort: (asc) {}),
            ),
          ],
          dataToRow: (Person person, int index) {
            return DataRow(cells: [
              DataCell(Text(person.name)),
              DataCell(Text(person.country)),
              DataCell(Text("${person.age}")),
            ]);
          },
          emptyBuilder: (context) => const Center(child: Text("No results found")),
          errorBuilder: (context, error) => Center(child: Text("Error: $error")),
          selectableColumns: true,
          selectedColumnsKey: "my_persons_table",
          showCheckboxColumn: true,
          onSelectedDataChanged: (selected) => debugPrint("${selected.length} rows selected"),
        ),
      ),
    );
  }
}
```

### `PageInfo`

`getData` receives a `PageInfo` object:

| Field | Type | Description |
|---|---|---|
| `pageIndex` | `int` | Zero-based current page index |
| `pageSize` | `int` | Number of rows requested |

### Key parameters

| Parameter | Type | Description |
|---|---|---|
| `getData` | `Future<List<T>> Function(PageInfo)` | Called on every page change |
| `getTotal` | `Future<int> Function()` | Called once; result is cached until `refreshPage()` |
| `columns` | `List<TableColumn>` | Column definitions with optional search/filter/sort |
| `dataToRow` | `DataRow Function(T, int)` | Converts a data item to a `DataRow` |
| `emptyBuilder` | `Widget Function(BuildContext)?` | Shown when data is empty |
| `initialLoading` | `Widget Function(BuildContext)?` | Shown before the first load completes |
| `errorBuilder` | `Widget Function(BuildContext, Object)?` | Shown on load error |
| `selectableColumns` | `bool` | Enables column visibility toggle menu |
| `selectedColumnsKey` | `String?` | SharedPreferences key for persisting column selection |

### Programmatic control

Access the state via a `GlobalKey<LazyPaginatedDataTableState>`:

```dart
final tableKey = GlobalKey<LazyPaginatedDataTableState<Person>>();

// Re-fetch from the server (clears total cache and sort state)
tableKey.currentState?.refreshPage();

// Force a UI rebuild without a network call
tableKey.currentState?.updateUI();

// Selection
tableKey.currentState?.selectAll([0, 1, 2]);
tableKey.currentState?.clearSelection();
tableKey.currentState?.selectCount; // int

// Listen to selection as a stream
tableKey.currentState?.selectedIndexes; // Stream<List<int>>
tableKey.currentState?.selectedValues;  // Stream<List<T>>
```

## Screenshots

![image 1](https://github.com/Oualitsen/lazy_paginated_data_table/blob/main/images/image1.png)
![image 2](https://github.com/Oualitsen/lazy_paginated_data_table/blob/main/images/image2.png)
![image 3](https://github.com/Oualitsen/lazy_paginated_data_table/blob/main/images/image3.png)
![image 4](https://github.com/Oualitsen/lazy_paginated_data_table/blob/main/images/image4.png)

## Related

If your Flutter app talks to a GraphQL API, check out [GraphLink](https://pub.dev/packages/graphlink) — a code generator that produces fully-typed Dart/Flutter clients from a `.graphql` schema with zero runtime dependency.
