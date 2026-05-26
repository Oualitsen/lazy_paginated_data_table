import 'dart:async';

Stream<R> combineLatest2<A, B, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  R Function(A a, B b) combiner,
) {
  late StreamController<R> controller;
  A? latestA;
  B? latestB;
  bool hasA = false;
  bool hasB = false;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  void tryEmit(StreamController<R> c) {
    if (hasA && hasB) c.add(combiner(latestA as A, latestB as B));
  }

  controller = StreamController<R>.broadcast(
    onListen: () {
      subA = streamA.listen(
        (a) { latestA = a; hasA = true; tryEmit(controller); },
        onError: controller.addError,
      );
      subB = streamB.listen(
        (b) { latestB = b; hasB = true; tryEmit(controller); },
        onError: controller.addError,
      );
    },
    onCancel: () {
      subA?.cancel();
      subB?.cancel();
    },
  );

  return controller.stream;
}
