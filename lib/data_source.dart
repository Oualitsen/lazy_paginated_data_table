import 'package:flutter/material.dart';
import 'package:lazy_paginated_data_table/indexed_data.dart';
import 'package:lazy_paginated_data_table/page_info.dart';
import 'package:rxdart/rxdart.dart';

class DataSourceTable<T> extends DataTableSource {
  final List<T> data;
  final DataRow Function(T data, int index) dataRow;
  final int total;
  final PageInfo pageInfo;
  final List<int> selectedColumnsIndices;

  final BehaviorSubject<Set<IndexedData<T>>> selectedIndexes;

  DataSourceTable({
    required this.data,
    required this.dataRow,
    required this.total,
    required this.selectedIndexes,
    required this.pageInfo,
    required this.selectedColumnsIndices,
  });

  @override
  DataRow? getRow(int index) {
    int _index = index;
    int offset = pageInfo.pageSize * pageInfo.pageIndex;
    _index -= offset;
    if (_index < 0) {
      return null;
    }

    if (_index < data.length) {
      var row = _dataToRow(data[_index], _index);
      if (row.selected) {
        _addSelectedIndex(_index, data[_index]);
      }
      return row;
    }
    return null;
  }

  void _addSelectedIndex(int index, T data) {
    final _selected = selectedIndexes.value;
    if (_selected.add(IndexedData(index, data))) {
      selectedIndexes.add(_selected);
    }
  }

  DataRow _dataToRow(T data, int index) {
    var result = dataRow(data, index);
    List<DataCell> cells = [];
    var sortedIndices = [...selectedColumnsIndices];

    sortedIndices.sort();
    for (var index in sortedIndices) {
      cells.add(result.cells[index]);
    }
    return DataRow(cells: cells);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => total;

  @override
  int get selectedRowCount => selectedIndexes.value.length;
}
