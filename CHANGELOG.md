## 0.0.1

## 0.0.3
Enhances the refresh method

## 0.0.4

Fixes row selection bug


## 0.0.5
Fixes some ui issues

## 0.0.6
Adds onSelectedDataChanged and onSelectedIndexesChanged listeners

## 0.0.7
Fixes some bugs

## 1.0.0
Fixes excessive getData calls
Caches getTotal call

## 1.0.1
Optional cache getTotal result

## 1.0.2
Calls getData and getTotal in parallel

## 2.0.0
Adds the possibility to select columns
### Breaking change
Your need to pass instance of `TableColumn` instead of `DataColumn` on `columns` field
## 2.1.0
Makes a Column always visible when no `key` is provided
Adds ability to change the label of selectable columns in the column selection menu

## 2.2.0
Adds Search support
Adds Filter support
Adds Sort support

## 2.2.1
updates README.md
## 2.2.2
Fixes minimal bugs
## 2.3.0
Adds initial loading widget
Fixes large rows per page issue

## 2.4.0
Removes rxdart dependency (replaced with internal BehaviorSubject and stream utilities)
Fixes stream subscription leak in TableColumn (subscriptions now managed via dispose)
Fixes sort config subscription leak (moved from widget constructor to initState/dispose)
Fixes selectAll/unselectAll crash on empty index list
Fixes dispose race condition: async load callbacks now check mounted before touching subjects
Removes local mutation methods (add, addAll, addFirst, addAllFirst, set, removeAt, removeWhere, sortData) — total count cannot be kept consistent with local mutations; use refreshPage() instead
Selection changes no longer trigger a full StreamBuilder rebuild (notifyListeners on existing source)
Adds emptyBuilder parameter for empty-state UI
Upgrades SDK constraint to Dart 3 (>=3.0.0 <4.0.0)
Replaces deprecated dataRowHeight with dataRowMinHeight and dataRowMaxHeight