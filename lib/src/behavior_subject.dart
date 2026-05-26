import 'dart:async';

class BehaviorSubject<T> extends StreamView<T> {
  final StreamController<T> _controller;
  T? _value;
  bool _hasValue = false;

  BehaviorSubject._(this._controller) : super(_controller.stream);

  factory BehaviorSubject() {
    final controller = StreamController<T>.broadcast();
    return BehaviorSubject._(controller);
  }

  factory BehaviorSubject.seeded(T value) {
    final subject = BehaviorSubject<T>();
    subject._value = value;
    subject._hasValue = true;
    return subject;
  }

  bool get hasValue => _hasValue;

  T get value {
    if (!_hasValue) throw StateError('No value has been added');
    return _value as T;
  }

  T? get valueOrNull => _hasValue ? _value : null;

  void add(T value) {
    _value = value;
    _hasValue = true;
    _controller.add(value);
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    _controller.addError(error, stackTrace);
  }

  Future<void> close() => _controller.close();

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final sub = _controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    if (_hasValue && onData != null) {
      onData(_value as T);
    }
    return sub;
  }
}
