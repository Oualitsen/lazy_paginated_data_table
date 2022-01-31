library lazy_paginated_data_table;

import 'dart:async';

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
  final Key? tableKey;
  final Widget Function(BuildContext context, int page, int pagesPerRow)?
      onPageLoading;

  final ValueSetter<bool?>? onSelectAll;

  final double horizontalMargin;

  final int? initialFirstRowIndex;
  final bool showCheckboxColumn;
  final bool sortAscending;
  final int? sortColumnIndex;
  const LazyPaginatedDataTable({
    Key? key,
    this.tableKey,
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
  }) : super(key: key);

  @override
  LazyPaginatedDataTableState<T> createState() =>
      LazyPaginatedDataTableState<T>();
}

class LazyPaginatedDataTableState<T> extends State<LazyPaginatedDataTable> {
  final _indexSubject = BehaviorSubject.seeded(
    PageInfo(pageSize: 10, pageIndex: 0),
  );
  final _countSubject = BehaviorSubject<int>();
  late final Future<List<T>> Function(PageInfo info) getData;

  final _dataSubject = BehaviorSubject<_DataList<T>>();
  final _progress = BehaviorSubject.seeded(false);
  final _selectIndexes = BehaviorSubject.seeded(<_IndexedData<T>>{});

  int get rowsPerPage => _indexSubject.value.pageSize;

  late final StreamSubscription _subscription;

  bool _listenToSelectionChanges = true;

  @override
  void initState() {
    widget
        .getTotal()
        .asStream()
        .doOnListen(() => _progress.add(true))
        .doOnError((p0, p1) => _dataSubject.addError(p0))
        .doOnDone(() => _progress.add(false))
        .listen((event) {
      _countSubject.add(event);
    });

    _subscription = Rx.combineLatest2(
            _indexSubject.flatMap(
              (pageInfo) => widget.getData(pageInfo).asStream().doOnListen(() {
                _listenToSelectionChanges = false;
                clearSelection();
                _progress.add(true);
              }).doOnDone(() => _progress.add(false)),
            ),
            _countSubject.stream,
            (a, b) => _DataList(a as List<T>, b as int))
        .doOnError((p0, p1) => _dataSubject.addError(p0))
        .listen((data) {
      _listenToSelectionChanges = true;
      _dataSubject.add(data);
    });

    _selectIndexes
        .where((event) => _listenToSelectionChanges && _countSubject.hasValue)
        .listen((event) {
      _countSubject.add(_countSubject.value);
    });

    super.initState();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _dataSubject.close();
    _indexSubject.close();
    _countSubject.close();
    _progress.close();
    _selectIndexes.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Object?>>(
        stream: Rx.combineLatest2(_dataSubject, _progress, (a, b) => [a, b]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildProgress(context, -1, rowsPerPage);
          }

          if (snapshot.hasError) {
            return _getError(context, snapshot.error!);
          }
          var _data = snapshot.data![0] as _DataList<T>;
          var __progress = snapshot.data![1] as bool;
          var pageInfo = _indexSubject.value;
          var offset = pageInfo.pageIndex * pageInfo.pageSize;
          var table = PaginatedDataTable(
            key: widget.tableKey,
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
                _indexSubject.add(
                    PageInfo(pageSize: rowsPerPage, pageIndex: currentIndex));
              }
            },
            onPageChanged: (int page) {
              int pageIndex = page == 0 ? 0 : page ~/ rowsPerPage;
              _indexSubject
                  .add(PageInfo(pageSize: rowsPerPage, pageIndex: pageIndex));
            },
            columns: widget.columns,
            source: _MyDataSourceTable(
              data: _data.list,
              dataRow: widget.dataToRow,
              total: _data.count,
              offset: offset,
              selectedIndexes: _selectIndexes,
              enableSelection: _listenToSelectionChanges,
            ),
          );

          return Stack(
            children: [
              table,
              if (__progress)
                Positioned(
                  child: _buildProgress(
                      context, pageInfo.pageIndex, pageInfo.pageSize),
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                ),
              StreamBuilder(
                builder: (context, snapshot) =>
                    Text("selected = ${_selectIndexes.value}"),
                stream: _selectIndexes,
              )
            ],
          );
        });
  }

  Widget _getError(BuildContext context, Object error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }
    final color = Theme.of(context).colorScheme.error;
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 32),
          Icon(
            Icons.error,
            color: color,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            "Could not load data",
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }

  ///refreshes the current page
  void refresh() {
    widget
        .getTotal()
        .asStream()
        .map((event) {
          _countSubject.add(event);
          return event;
        })
        .doOnError((p0, p1) {
          _dataSubject.addError(p0);
        })
        .doOnListen(() => _progress.add(true))
        .doOnDone(() => _progress.add(false))
        .listen(_countSubject.add);
  }

  void clearSelection() {
    var _selected = _selectIndexes.value;
    if (_selected.isNotEmpty) {
      _selected.clear();
      _selectIndexes.add(_selected);
    }
  }

  /// used only for selection options

  ///This method is used to refresh the current page without making a network call
  void refreshPage() {
    widget
        .getTotal()
        .asStream()
        .doOnError((p0, p1) => _dataSubject.addError(p0))
        .doOnListen(() => _progress.add(true))
        .doOnDone(() => _progress.add(false))
        .listen(_countSubject.add);
  }

  void set(T data, int index) {
    var _data = _dataSubject.value;
    var _list = _data.list;
    _list[index] = data;
    _dataSubject.add(_DataList(_list, _data.count));
  }

  int get selectCount => _selectIndexes.value.length;

  /// adds an element to the table
  void addAll(List<T> data) {
    var _data = _dataSubject.value;
    _dataSubject.add(_DataList([..._data.list, ...data], _data.count + 1));
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
      _data.list.removeAt(index);
      _dataSubject.add(_DataList(_data.list, _data.count - 1));
      return true;
    }
    return false;
  }

  List<T> removeWhere(bool Function(T data) test) {
    var _data = _dataSubject.value.list;
    List<T> result = [];

    _data.removeWhere((element) {
      var _remove = test(element);
      if (_remove) {
        result.add(element);
      }
      return _remove;
    });
    if (result.isNotEmpty) {
      _dataSubject
          .add(_DataList(_data, _dataSubject.value.count - result.length));
    }
    return result;
  }

  void addAllFirst(List<T> data) {
    var _data = _dataSubject.value;
    _dataSubject.add(_DataList([...data, ..._data.list], _data.count + 1));
  }

  /// sort the current page
  void sortData(int Function(T a, T b) compare) {
    var _data = _dataSubject.value;
    var _list = _data.list.toList(growable: true);
    _list.sort(compare);
    _dataSubject.add(_DataList(_list, _data.count));
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
    var __data =
        indexes.map(set.remove).reduce((value, element) => value || element);
    if (__data) {
      _selectIndexes.add(set);
    }
  }

  void unselect(int index) {
    unselectAll([index]);
  }

  Stream<List<int>> get selectedIndexes =>
      _selectIndexes.map((event) => event.map((e) => e.index).toList());
  Stream<List<T>> get selectedValues =>
      _selectIndexes.map((event) => event.map((e) => e.data).toList());

  @override
  LazyPaginatedDataTable<T> get widget =>
      super.widget as LazyPaginatedDataTable<T>;
}

class _DataList<T> {
  final List<T> list;
  final int count;

  _DataList(this.list, this.count);
}

class _IndexedData<T> {
  final int index;
  final T data;

  const _IndexedData(this.index, this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _IndexedData &&
          runtimeType == other.runtimeType &&
          index == other.index;

  @override
  int get hashCode => index.hashCode;
}

class _MyDataSourceTable<T> extends DataTableSource {
  final List<T> data;
  final DataRow Function(T data, int index) dataRow;
  final int total;
  final int offset;
  final bool enableSelection;

  final BehaviorSubject<Set<_IndexedData<T>>> selectedIndexes;

  _MyDataSourceTable({
    required this.data,
    required this.dataRow,
    required this.total,
    required this.offset,
    required this.selectedIndexes,
    required this.enableSelection,
  });

  @override
  DataRow? getRow(int index) {
    int _index = index - offset;
    if (_index < 0) {
      _index *= -1;
    }

    if (_index < data.length) {
      var row = dataRow(data[_index], _index);
      if (enableSelection && row.selected) {
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
