import 'dart:async';

extension DebounceExtension<T> on Stream<T> {
  Stream<T> debounceTime(Duration duration) {
    late StreamController<T> controller;
    Timer? timer;
    StreamSubscription<T>? sub;

    controller = StreamController<T>.broadcast(
      onListen: () {
        sub = listen(
          (value) {
            timer?.cancel();
            timer = Timer(duration, () => controller.add(value));
          },
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            controller.close();
          },
        );
      },
      onCancel: () {
        timer?.cancel();
        sub?.cancel();
      },
    );

    return controller.stream;
  }
}
