class IndexedData<T> {
  final int index;
  final T data;

  const IndexedData(this.index, this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexedData && runtimeType == other.runtimeType && index == other.index;

  @override
  int get hashCode => index.hashCode;
}
