import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class TableColumn<T> {
  final String? key;
  final String? keyLabel;
  final Widget label;
  final String? tooltip;
  final bool numeric;

  final SearchConfig? searchConfig;
  final FilterConfig<T>? filterConfig;
  final SortConfig? sortConfig;

  TableColumn({
    this.key,
    this.keyLabel,
    required this.label,
    this.tooltip,
    this.numeric = false,
    this.sortConfig,
    this.searchConfig,
    this.filterConfig,
  })  : assert(!(key == null && keyLabel != null), "key cannot be null when keyLabel is provided"),
        assert(!(searchConfig != null && filterConfig != null),
            "You cannot provide both filterConfig and filterConfig");

  DataColumn toDataColumn() {
    return DataColumn(label: _createLabel(), numeric: numeric, onSort: null, tooltip: tooltip);
  }

  Widget _createLabel() {
    if (searchConfig != null) {
      return _createSearchHeader();
    }
    if (filterConfig != null) {
      return _createFilterHeader();
    }
    return _createSortLabel();
  }

  Widget _createSortLabel() {
    if (sortConfig == null) {
      return label;
    } else {
      return InkWell(
        onTap: () {
          sortConfig!.toggleSort();
        },
        child: Row(children: [
          label,
          const SizedBox(width: 5),
          StreamBuilder<bool?>(
              stream: sortConfig!.sortSubject,
              initialData: sortConfig!.sortSubject.valueOrNull,
              builder: (context, snapshot) {
                var data = snapshot.data;
                if (data != null) {
                  if (data) {
                    return sortConfig!.ascIcon;
                  } else {
                    return sortConfig!.desIcon;
                  }
                }
                return SizedBox(width: sortConfig!.ascIcon.size ?? 24);
              })
        ]),
      );
    }
  }

  Widget _createFilterHeader() {
    var filterConfig = this.filterConfig!;
    filterConfig.selectedItemsSubject.skip(1).debounceTime(filterConfig.debounceTime).listen((value) {
      filterConfig.onFilter(value);
    });
    return Row(
      children: [
        PopupMenuButton<FilterItem>(
            child: filterConfig.filterIcon,
            itemBuilder: (context) => [
                  PopupMenuItem<FilterItem>(
                    onTap: () {
                      filterConfig.toggleSelectAll();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StreamBuilder<List<T>>(
                            stream: filterConfig.selectedItemsSubject,
                            initialData: filterConfig.selectedItemsSubject.valueOrNull,
                            builder: (context, snapshot) {
                              var data = snapshot.data;
                              if (data == null) {
                                return const SizedBox.shrink();
                              }
                              return Checkbox(
                                  value: data.length == filterConfig.items.length,
                                  onChanged: (newValue) {
                                    if (newValue != null) {
                                      filterConfig.toggleSelectAll();
                                    }
                                  });
                            }),
                        const SizedBox(width: 10),
                        Text(filterConfig.selectAllLabel),
                      ],
                    ),
                  ),
                  ...filterConfig.items.map((item) => PopupMenuItem<FilterItem>(
                        onTap: () {
                          filterConfig.updateSelected(item.value);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StreamBuilder<List<T>>(
                                stream: filterConfig.selectedItemsSubject,
                                initialData: filterConfig.selectedItemsSubject.valueOrNull,
                                builder: (context, snapshot) {
                                  var data = snapshot.data;
                                  if (data == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Checkbox(
                                      value: data.contains(item.value),
                                      onChanged: (newValue) {
                                        if (newValue != null) {
                                          filterConfig.updateSelected(item.value);
                                        }
                                      });
                                }),
                            const SizedBox(width: 10),
                            Text(item.label),
                          ],
                        ),
                        value: item,
                      ))
                ]),
        const SizedBox(width: 10),
        _createSortLabel(),
      ],
    );
  }

  Widget _createSearchHeader() {
    var searchConfig = this.searchConfig!;
    var subject = searchConfig.searchintSubject;
    searchConfig.textSubject
        .skip(1)
        .debounceTime(searchConfig.debounceTime)
        .listen((text) => searchConfig.onSearch(text));

    return StreamBuilder<bool>(
        stream: subject,
        initialData: subject.valueOrNull,
        builder: (context, snapshot) {
          var searching = snapshot.data ?? false;
          if (searching) {
            return Row(
              children: [
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    onChanged: (text) => searchConfig.textSubject.add(text.isEmpty ? null : text),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 5, top: 5),
                      border: searchConfig.border,
                      hintText: searchConfig.hint,
                      suffix: InkWell(
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.clear, size: 16),
                        ),
                        onTap: () {
                          subject.add(false);
                          searchConfig.textSubject.add(null);
                        },
                      ),
                    ),
                  ),
                )
              ],
            );
          }
          return Row(
            children: [
              InkWell(
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.search, size: 16),
                ),
                onTap: () {
                  searchConfig.searchintSubject.add(true);
                },
              ),
              const SizedBox(width: 10),
              _createSortLabel(),
            ],
          );
        });
  }
}

class FilterConfig<T> {
  final List<FilterItem<T>> items;
  final void Function(List<T>) onFilter;
  final BehaviorSubject<List<T>> selectedItemsSubject;
  final String selectAllLabel;
  final Icon filterIcon;

  ///
  /// this is necessary to avoid unnecessary calls to the data source.
  ///
  final Duration debounceTime;
  FilterConfig({
    required this.items,
    required this.onFilter,
    this.selectAllLabel = "Select all",
    this.debounceTime = const Duration(milliseconds: 500),
    this.filterIcon = const Icon(Icons.filter_alt, size: 16),
  })  : assert(items.isNotEmpty, "items should not be empty"),
        selectedItemsSubject = BehaviorSubject<List<T>>.seeded(items.map((e) => e.value).toList());

  void updateSelected(T item) {
    var selected = selectedItemsSubject.value;
    if (selected.contains(item)) {
      selected.remove(item);
    } else {
      selected.add(item);
    }
    selectedItemsSubject.add(selected);
  }

  void toggleSelectAll() {
    var selected = selectedItemsSubject.value;
    if (selected.length != items.length) {
      selectedItemsSubject.add(items.map((e) => e.value).toList());
    } else {
      selectedItemsSubject.add(<T>[]);
    }
  }
}

class SearchConfig {
  final Duration debounceTime;
  final String hint;
  final void Function(String?) onSearch;
  final OutlineInputBorder border;
  final BehaviorSubject<bool> searchintSubject = BehaviorSubject.seeded(false);
  final BehaviorSubject<String?> textSubject = BehaviorSubject.seeded(null);
  SearchConfig(
      {this.debounceTime = const Duration(milliseconds: 500),
      this.hint = "Search",
      this.border = const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(100))),
      required this.onSearch});
}

class FilterItem<T> {
  final String label;
  final T value;
  FilterItem({required this.label, required this.value});
}

class SortConfig {
  final void Function(bool asc) onSort;
  final Icon ascIcon;
  final Icon desIcon;
  final BehaviorSubject<bool?> sortSubject;

  SortConfig({
    required this.onSort,
    this.ascIcon = const Icon(Icons.arrow_drop_up),
    this.desIcon = const Icon(Icons.arrow_drop_down),
  }) : sortSubject = BehaviorSubject<bool?>.seeded(null) {
    sortSubject.skip(1).where((event) => event != null).map((e) => e!).listen((value) => onSort(value));
  }

  void toggleSort() {
    var current = sortSubject.valueOrNull;
    if (current == null) {
      sortSubject.add(true);
    } else if (current) {
      sortSubject.add(false);
    } else {
      sortSubject.add(true);
    }
  }
}
