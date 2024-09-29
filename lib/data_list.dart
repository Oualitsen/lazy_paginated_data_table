import 'package:lazy_paginated_data_table/page_info.dart';

class DataList<T> {
  final List<T> list;
  final int count;
  final PageInfo pageInfo;
  DataList(this.list, this.count, this.pageInfo);

  @override
  String toString() {
    return "{'list.length' = ${list.length},  'count' = $count}";
  }
}
