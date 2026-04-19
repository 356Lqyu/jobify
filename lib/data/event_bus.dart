import 'dart:async';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _jobSavedController = StreamController<String>.broadcast();

  Stream<String> get onJobSavedChanged => _jobSavedController.stream;

  void notifyJobSavedChanged(String jobId) {
    _jobSavedController.add(jobId);
  }

  void dispose() {
    _jobSavedController.close();
  }
}