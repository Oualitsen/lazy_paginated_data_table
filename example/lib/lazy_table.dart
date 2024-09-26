library lazy_paginated_data_table;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class LazyPaginatedDataTable<T> extends StatefulWidget {
  final Future<List<T>> Function(PageInfo info) getData;
  final Future<int> Function() getTotal;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final List<DataColumn> columns;
  final DataRow Function(T data, int indexInCurrentPage) dataToRow;
  final Widget? header;
  final List<Widget>? actions;
  final bool showFirstLastButtons;
  final Color? arrowHeadColor;
  final List<int> availableRowsPerPage;
  final double? checkboxHorizontalMargin;
  final double columnSpacing;
  final double dataRowHeight;
  final DragStartBehavior dragStartBehavior;
  final double headingRowHeight;
  final Widget Function(BuildContext context, int page, int pagesPerRow)? onPageLoading;

  final ValueSetter<bool?>? onSelectAll;

  final double horizontalMargin;

  final int? initialFirstRowIndex;
  final bool showCheckboxColumn;
  final bool sortAscending;
  final int? sortColumnIndex;

  final void Function(List<int> selectedIndexes)? onSelectedIndexesChanged;
  final void Function(List<T> selectedIndexes)? onSelectedDataChanged;

  const LazyPaginatedDataTable({
    Key? key,
    this.arrowHeadColor,
    required this.getData,
    required this.getTotal,
    required this.columns,
    required this.dataToRow,
    this.dragStartBehavior = DragStartBehavior.start,
    this.dataRowHeight = kMinInteractiveDimension,
    this.columnSpacing = 56.0,
    this.headingRowHeight = 56.0,
    this.checkboxHorizontalMargin,
    this.horizontalMargin = 24.0,
    this.availableRowsPerPage = const [10, 20, 50, 100],
    this.showFirstLastButtons = false,
    this.showCheckboxColumn = true,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.initialFirstRowIndex,
    this.onSelectAll,
    this.onPageLoading,
    this.header,
    this.errorBuilder,
    this.actions,
    this.onSelectedDataChanged,
    this.onSelectedIndexesChanged,
  }) : super(key: key);

  @override
  LazyPaginatedDataTableState<T> createState() => LazyPaginatedDataTableState<T>();
}

class LazyPaginatedDataTableState<T> extends State<LazyPaginatedDataTable> {
  final _emptyData = _DataList(<T>[], 0, PageInfo(pageIndex: 0, pageSize: 0));

  final _indexSubject = BehaviorSubject.seeded(
    PageInfo(pageSize: 10, pageIndex: 0),
  );
  late final Future<List<T>> Function(PageInfo info) getData;

  final _dataSubject = BehaviorSubject<_DataList<T>>();
  final _progress = BehaviorSubject.seeded(false);
  final _selectIndexes = BehaviorSubject.seeded(<_IndexedData<T>>{});

  int get rowsPerPage => _indexSubject.value.pageSize;

  final _key = GlobalKey<PaginatedDataTableState>();
  bool _disabledDataLoading = false;

  int? _total;

  @override
  void initState() {
    _indexSubject.where((event) => !_disabledDataLoading).listen((pageInfo) async {
      try {
        _progress.add(true);
        var count = _total == null ? await widget.getTotal() : _total!;
        _total = count;
        var data = await widget.getData(pageInfo);
        clearSelection();
        _addData(_DataList(data, count, pageInfo));
      } catch (err, st) {
        print(st);
        _dataSubject.addError(err);
      } finally {
        _progress.add(false);
      }
    });

    _selectIndexes.where((event) => _dataSubject.hasValue).listen((event) {
      _dataSubject.add(_dataSubject.value);
    });

    if (widget.onSelectedIndexesChanged != null || widget.onSelectedDataChanged != null) {
      _selectIndexes.listen((value) {
        if (widget.onSelectedIndexesChanged != null) {
          widget.onSelectedIndexesChanged!(value.map((e) => e.index).toList());
        }
        if (widget.onSelectedDataChanged != null) {
          widget.onSelectedDataChanged!(value.map((e) => e.data).toList());
        }
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    _dataSubject.close();
    _indexSubject.close();
    _progress.close();
    _selectIndexes.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_DataList<T>>(
        stream: _dataSubject,
        builder: (context, snapshot) {
          var _data = snapshot.data ?? _emptyData;

          var pageInfo = _indexSubject.value;
          //var firstIndex =
          var table = PaginatedDataTable(
            key: _key,
            header: widget.header,
            actions: widget.actions,
            rowsPerPage: rowsPerPage,
            arrowHeadColor: widget.arrowHeadColor,
            availableRowsPerPage: widget.availableRowsPerPage,
            checkboxHorizontalMargin: widget.checkboxHorizontalMargin,
            columnSpacing: widget.columnSpacing,
            dataRowHeight: widget.dataRowHeight,
            dragStartBehavior: widget.dragStartBehavior,
            headingRowHeight: widget.headingRowHeight,
            horizontalMargin: widget.horizontalMargin,
            initialFirstRowIndex: widget.initialFirstRowIndex,
            onSelectAll: widget.onSelectAll,
            showCheckboxColumn: widget.showCheckboxColumn,
            sortAscending: widget.sortAscending,
            sortColumnIndex: widget.sortColumnIndex,
            showFirstLastButtons: widget.showFirstLastButtons,
            onRowsPerPageChanged: (int? rowsPerPage) {
              if (rowsPerPage != this.rowsPerPage && rowsPerPage != null) {
                var currentIndex = _indexSubject.value.pageIndex;
                var oldRowPerPage = _indexSubject.value.pageSize;
                _indexSubject.add(PageInfo(pageSize: rowsPerPage, pageIndex: currentIndex));

                if (oldRowPerPage > rowsPerPage) {
                  _disabledDataLoading = true;
                  _key.currentState!.pageTo(currentIndex + 1);
                  _key.currentState!.pageTo(currentIndex);
                  _disabledDataLoading = false;
                }
              }
            },
            onPageChanged: (int page) {
              int pageIndex = page == 0 ? 0 : page ~/ rowsPerPage;
              _indexSubject.add(PageInfo(pageSize: rowsPerPage, pageIndex: pageIndex));
            },
            columns: widget.columns,
            source: _MyDataSourceTable(
              data: _data.list,
              dataRow: widget.dataToRow,
              total: _data.count,
              selectedIndexes: _selectIndexes,
              pageInfo: _data.pageInfo,
            ),
          );

          return Stack(
            children: [
              table,

              ///Central progress widget
              StreamBuilder<bool>(
                  stream: _progress,
                  builder: (context, snapshot) {
                    if (snapshot.data ?? false) {
                      return Positioned(
                        child: _buildProgress(context, pageInfo.pageIndex, pageInfo.pageSize),
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                      );
                    }
                    return const SizedBox.shrink();
                  }),

              ///Show the error in the center if applicable
              if (snapshot.hasError)
                Positioned(
                  child: _getError(context, snapshot.error!),
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                ),
            ],
          );
        });
  }

  ///this method sets the data without calling the rebuild
  void _setData(List<T> list, int newCount) {
    _addData(_DataList(list, newCount, _dataSubject.value.pageInfo));
  }

  Widget _getError(BuildContext context, Object error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }
    final color = Theme.of(context).colorScheme.error;
    String errorText = "Could not load data";

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error,
            color: color,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            errorText,
            style: TextStyle(color: color),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: refreshPage, child: const Text("Retry"))
        ],
      ),
    );
  }

  ///calls both getTotal and getData methods and updates the ui
  void refreshPage() {
    _total = null;
    _indexSubject.add(_indexSubject.value);
  }

  /// update current page without any network call
  /// Use this method as you would use setState((){}) of a stateful widget
  void updateUI() {
    if (_dataSubject.hasValue) {
      clearSelection();
      _dataSubject.add(_dataSubject.value);
    }
  }

  void clearSelection() {
    var _selected = _selectIndexes.value;
    if (_selected.isNotEmpty) {
      _selected.clear();
      _selectIndexes.add(_selected);
    }
  }

  /// updates the index-th value in the currently loaded page!
  ///

  void set(T data, int index) {
    var _data = _dataSubject.value;
    var _list = _data.list;
    _list[index] = data;
    _addData(_DataList(_list, _data.count, _data.pageInfo));
  }

  int get selectCount => _selectIndexes.value.length;

  /// adds an element to the table
  void addAll(List<T> list) {
    var _data = _dataSubject.value;
    _setData([..._data.list, ...list], _data.count + list.length);
  }

  void _addData(_DataList<T> dataList) {
    _dataSubject.add(dataList);
  }

  void add(T data) {
    addAll([data]);
  }

  void addFirst(T data) {
    addAllFirst([data]);
  }

  bool removeAt(int index) {
    var _data = _dataSubject.value;
    if (_data.list.length < index && index >= 0) {
      var value = _data.list.removeAt(index);
      if (value != null) {
        _removeFromSelection([value]);
        _setData(_data.list, _data.count - 1);
        return true;
      }
    }
    return false;
  }

  List<T> removeWhere(bool Function(T data) test) {
    final _dataList = _dataSubject.value;
    final _data = _dataList.list;
    final count = _dataList.count;

    List<T> result = [];

    _data.removeWhere((element) {
      var _remove = test(element);
      if (_remove) {
        result.add(element);
      }
      return _remove;
    });
    if (result.isNotEmpty) {
      _removeFromSelection(result);
      _setData(_data, count - result.length);
    }
    return result;
  }

  void _removeFromSelection(List<T> list) {
    var _data = _selectIndexes.value;
    _data.removeWhere((element) => list.contains(element.data));
    _selectIndexes.add(_data);
  }

  void addAllFirst(List<T> data) {
    var _data = _dataSubject.value;
    _setData([...data, ..._data.list], _data.count + data.length);
  }

  /// sort the current page
  void sortData(int Function(T a, T b) compare) {
    var _data = _dataSubject.value;
    var _list = _data.list.toList(growable: true);
    _list.sort(compare);
    _addData(_DataList(_list, _data.count, _data.pageInfo));
  }

  Widget _buildProgress(BuildContext context, int page, int pageSize) {
    if (widget.onPageLoading != null) {
      return widget.onPageLoading!(context, page, pageSize);
    }
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  void selectAll(List<int> indexes) {
    var set = _selectIndexes.value;
    var data = indexes
        .map((index) => _IndexedData(index, _dataSubject.value.list[index]))
        .map(set.add)
        .reduce((value, element) => value || element);
    if (data) {
      _selectIndexes.add(set);
    }
  }

  void select(int index) {
    selectAll([index]);
  }

  void unselectAll(List<int> indexes) {
    var set = _selectIndexes.value;
    var __data = indexes.map(set.remove).reduce((value, element) => value || element);
    if (__data) {
      _selectIndexes.add(set);
    }
  }

  void unselect(int index) {
    unselectAll([index]);
  }

  Stream<List<int>> get selectedIndexes => _selectIndexes.map((event) => event.map((e) => e.index).toList());

  Stream<List<T>> get selectedValues => _selectIndexes.map((event) => event.map((e) => e.data).toList());

  @override
  LazyPaginatedDataTable<T> get widget => super.widget as LazyPaginatedDataTable<T>;
}

class _MyDataSourceTable<T> extends DataTableSource {
  final List<T> data;
  final DataRow Function(T data, int index) dataRow;
  final int total;
  final PageInfo pageInfo;

  final BehaviorSubject<Set<_IndexedData<T>>> selectedIndexes;

  _MyDataSourceTable({
    required this.data,
    required this.dataRow,
    required this.total,
    required this.selectedIndexes,
    required this.pageInfo,
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
      var row = dataRow(data[_index], _index);
      if (row.selected) {
        _addSelectedIndex(_index, data[_index]);
      }
      return row;
    }
    return null;
  }

  void _addSelectedIndex(int index, T data) {
    final _selected = selectedIndexes.value;
    if (_selected.add(_IndexedData(index, data))) {
      selectedIndexes.add(_selected);
    }
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => total;

  @override
  int get selectedRowCount => selectedIndexes.value.length;
}

class PageInfo {
  final int pageSize;
  final int pageIndex;

  PageInfo({
    required this.pageSize,
    required this.pageIndex,
  });
}

class _DataList<T> {
  final List<T> list;
  final int count;
  final PageInfo pageInfo;
  _DataList(this.list, this.count, this.pageInfo);

  @override
  String toString() {
    return "{'list.length' = ${list.length},  'count' = $count}";
  }
}

class _IndexedData<T> {
  final int index;
  final T data;

  const _IndexedData(this.index, this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _IndexedData && runtimeType == other.runtimeType && index == other.index;

  @override
  int get hashCode => index.hashCode;
}
