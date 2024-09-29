library lazy_paginated_data_table;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lazy_paginated_data_table/data_list.dart';
import 'package:lazy_paginated_data_table/data_source.dart';
import 'package:lazy_paginated_data_table/index_label.dart';
import 'package:lazy_paginated_data_table/indexed_data.dart';
import 'package:lazy_paginated_data_table/page_info.dart';
import 'package:lazy_paginated_data_table/table_column.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LazyPaginatedDataTable<T> extends StatefulWidget {
  final Future<List<T>> Function(PageInfo info) getData;
  final Future<int> Function() getTotal;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final List<TableColumn> columns;
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
  final bool selectableColumns;
  final int minSelectedColumns;
  // when provided, any change will NOT be persisted
  final List<String>? selectedColumns;
  final ValueChanged<List<String>>? onColumnSelectionChanged;

  /// saves selected columns
  final String? selectedColumnsKey;

  final void Function(List<int> selectedIndexes)? onSelectedIndexesChanged;
  final void Function(List<T> selectedIndexes)? onSelectedDataChanged;

  LazyPaginatedDataTable({
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
    this.selectableColumns = false,
    this.minSelectedColumns = 1,
    this.selectedColumns,
    this.selectedColumnsKey,
    this.onColumnSelectionChanged,
  })  : assert(minSelectedColumns >= 0, "minSelectedColumns must be greater or equals 0"),
        assert(selectedColumns == null && selectedColumnsKey != null,
            "selectedColumnsKey cannot be null when selectedColumns is not null"),
        assert(selectableColumns && columns.map((col) => col.key).where((key) => key != null).isNotEmpty,
            "You need to provide at least one column having key not null"),
        super(key: key) {
    _getSortConfigs().forEach((sortConfig) {
      sortConfig.sortSubject.where((event) => event != null).listen((value) {
        _getSortConfigs().where((element) => element != sortConfig).forEach((sc) {
          sc.sortSubject.add(null);
        });
      });
    });
  }

  List<SortConfig> _getSortConfigs() {
    return columns.where((element) => element.sortConfig != null).map((e) => e.sortConfig!).toList();
  }

  @override
  LazyPaginatedDataTableState<T> createState() => LazyPaginatedDataTableState<T>();
}

class LazyPaginatedDataTableState<T> extends State<LazyPaginatedDataTable> {
  final _indexSubject = BehaviorSubject.seeded(
    PageInfo(pageSize: 10, pageIndex: 0),
  );
  late final Future<List<T>> Function(PageInfo info) getData;

  final _dataSubject = BehaviorSubject<DataList<T>>();
  final _progress = BehaviorSubject.seeded(false);
  final _selectIndexes = BehaviorSubject.seeded(<IndexedData<T>>{});

  int get rowsPerPage => _indexSubject.value.pageSize;

  final _key = GlobalKey<PaginatedDataTableState>();

  final _seletedColumns = BehaviorSubject<List<String>>();

  bool _disabledDataLoading = false;
  final _showSelectColumnsWidgetSubject = BehaviorSubject<bool>();
  final _colIndex = <String, IndexLabel>{};

  int? _total;

  @override
  void initState() {
    _initColIndex();
    _showSelectColumnsWidgetSubject.add(widget.selectableColumns);

    _indexSubject.where((event) => !_disabledDataLoading).listen((pageInfo) async {
      try {
        _progress.add(true);
        var count = _total == null ? await widget.getTotal() : _total!;
        _total = count;
        var data = await widget.getData(pageInfo);
        clearSelection();
        _addData(DataList(data, count, pageInfo));
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
    _seletedColumns.listen((cols) => _saveSelectedColumns(cols));
    _seletedColumns
        .where((cols) => widget.onColumnSelectionChanged != null)
        .listen((cols) => widget.onColumnSelectionChanged!.call(cols));
    _getSavedSelectedColumns().then(_seletedColumns.add);
    super.initState();
  }

  void _initColIndex() {
    for (var index = 0; index < widget.columns.length; index++) {
      var col = widget.columns[index];
      if (col.key != null) {
        _colIndex[col.key!] = IndexLabel(index: index, columnLabel: col.keyLabel);
      }
    }
  }

  Future<List<String>> _getSavedSelectedColumns() async {
    if (widget.selectedColumns != null) {
      return widget.selectedColumns!;
    }
    var sp = await SharedPreferences.getInstance();
    try {
      var data = sp.getStringList(widget.selectedColumnsKey!);
      if (data == null || data.isEmpty) {
        return _getSelectableColumnNames();
      }
      return data.where((key) => _colIndex.containsKey(key)).toList();
    } catch (err) {
      return _getSelectableColumnNames();
    }
  }

  List<String> _getSelectableColumnNames() {
    return _colIndex.keys.toList();
  }

  void _saveSelectedColumns(List<String> cols) {
    if (widget.selectedColumns == null) {
      SharedPreferences.getInstance().then((sp) => sp.setStringList(widget.selectedColumnsKey!, cols));
    }
  }

  @override
  void dispose() {
    _dataSubject.close();
    _indexSubject.close();
    _progress.close();
    _selectIndexes.close();
    super.dispose();
  }

  List<int> _getSelectedIndices() {
    var cols = _seletedColumns.valueOrNull;
    if (cols == null) {
      return [];
    }

    var result = <int>[];
    for (var col in cols) {
      result.add(_colIndex[col]!.index);
    }
    for (int i = 0; i < widget.columns.length; i++) {
      var column = widget.columns[i];
      if (column.key == null) {
        result.add(i);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
        stream: Rx.combineLatest2(_dataSubject, _seletedColumns, (a, b) => [a, b]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }
          DataList<T> _data = snapshot.data!.first as DataList<T>;

          var pageInfo = _indexSubject.value;
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
            columns: _getColomuns(),
            source: DataSourceTable(
              data: _data.list,
              dataRow: widget.dataToRow,
              total: _data.count,
              selectedIndexes: _selectIndexes,
              pageInfo: _data.pageInfo,
              selectedColumnsIndices: _getSelectedIndices(),
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
              StreamBuilder<bool>(
                  stream: _showSelectColumnsWidgetSubject,
                  initialData: _showSelectColumnsWidgetSubject.valueOrNull,
                  builder: (context, snapshot) {
                    var show = snapshot.data ?? false;
                    if (!show) {
                      return const SizedBox.shrink();
                    }

                    return Positioned(
                      child: _columnSelectWidget(),
                      right: 10,
                      top: 10,
                    );
                  }),
            ],
          );
        });
  }

  bool _shouldBeDisabled(String key) {
    var cols = _seletedColumns.valueOrNull ?? [];
    if (!cols.contains(key)) {
      return false;
    }
    return cols.length <= widget.minSelectedColumns;
  }

  Widget _columnSelectWidget() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (!_shouldBeDisabled(value)) {
          _updateSelected(value);
        }
      },
      child: const Icon(Icons.more_vert),
      itemBuilder: (context) => _colIndex.keys
          .map((key) => PopupMenuItem<String>(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<List<String>>(
                        stream: _seletedColumns,
                        initialData: _seletedColumns.valueOrNull,
                        builder: (context, snapshot) {
                          var cols = snapshot.data;
                          if (cols == null) {
                            return const SizedBox.shrink();
                          }
                          return Checkbox(
                              value: cols.contains(key),
                              onChanged: _shouldBeDisabled(key)
                                  ? null
                                  : (newValue) {
                                      if (newValue != null) {
                                        _updateSelected(key);
                                      }
                                    });
                        }),
                    const SizedBox(width: 10),
                    Text(_colIndex[key]?.columnLabel ?? key),
                  ],
                ),
                value: key,
              ))
          .toList(),
    );
  }

  void _updateSelected(String key) {
    var _cols = _seletedColumns.valueOrNull;
    if (_cols == null) {
      return;
    }

    if (_isSelected(key)) {
      _cols.remove(key);
    } else {
      _cols.add(key);
    }
    _seletedColumns.add(_cols);
  }

  bool _isSelected(String key) {
    var _cols = _seletedColumns.valueOrNull ?? [];
    return _cols.contains(key);
  }

  List<DataColumn> _getColomuns() {
    if (widget.selectableColumns) {
      final columns = widget.columns;
      var _cols = _seletedColumns.valueOrNull;
      if (_cols == null) {
        return [];
      }
      return columns
          .where((element) => element.key == null || _cols.contains(element.key))
          .map((e) => e.toDataColumn())
          .toList();
    }
    return widget.columns.map((e) => e.toDataColumn()).toList();
  }

  ///this method sets the data without calling the rebuild
  void _setData(List<T> list, int newCount) {
    _addData(DataList(list, newCount, _dataSubject.value.pageInfo));
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
    _addData(DataList(_list, _data.count, _data.pageInfo));
  }

  int get selectCount => _selectIndexes.value.length;

  /// adds an element to the table
  void addAll(List<T> list) {
    var _data = _dataSubject.value;
    _setData([..._data.list, ...list], _data.count + list.length);
  }

  void _addData(DataList<T> dataList) {
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
    final dataList = _dataSubject.value;
    final _data = dataList.list;
    final count = dataList.count;

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
    _addData(DataList(_list, _data.count, _data.pageInfo));
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
        .map((index) => IndexedData(index, _dataSubject.value.list[index]))
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
