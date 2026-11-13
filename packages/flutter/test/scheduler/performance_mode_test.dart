// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

class _RecordingPlatformDispatcher extends TestPlatformDispatcher {
  _RecordingPlatformDispatcher({required super.platformDispatcher});

  final List<DartPerformanceMode> requests = <DartPerformanceMode>[];

  @override
  void requestDartPerformanceMode(DartPerformanceMode mode) {
    requests.add(mode);
    super.requestDartPerformanceMode(mode);
  }
}

class _PerformanceModeTestBinding extends AutomatedTestWidgetsFlutterBinding {
  late final _RecordingPlatformDispatcher _platformDispatcher = _RecordingPlatformDispatcher(
    platformDispatcher: super.platformDispatcher,
  );

  @override
  _RecordingPlatformDispatcher get platformDispatcher => _platformDispatcher;
}

void main() {
  final binding = _PerformanceModeTestBinding();

  setUp(() {
    binding.platformDispatcher.requests.clear();
  });

  test('PerformanceModeHandler make one request', () async {
    final PerformanceModeRequestHandle? requestHandle = binding.requestPerformanceMode(
      DartPerformanceMode.latency,
    );
    expect(requestHandle, isNotNull);
    expect(binding.debugGetRequestedPerformanceMode(), equals(DartPerformanceMode.latency));
    expect(binding.platformDispatcher.requests, <DartPerformanceMode>[DartPerformanceMode.latency]);
    requestHandle?.dispose();
    expect(binding.debugGetRequestedPerformanceMode(), isNull);
    expect(binding.platformDispatcher.requests, <DartPerformanceMode>[
      DartPerformanceMode.latency,
      DartPerformanceMode.balanced,
    ]);
  });

  test('PerformanceModeHandler make conflicting requests', () async {
    final PerformanceModeRequestHandle? requestHandle1 = binding.requestPerformanceMode(
      DartPerformanceMode.latency,
    );
    expect(requestHandle1, isNotNull);

    final PerformanceModeRequestHandle? requestHandle2 = binding.requestPerformanceMode(
      DartPerformanceMode.throughput,
    );
    expect(requestHandle2, isNull);

    expect(binding.debugGetRequestedPerformanceMode(), equals(DartPerformanceMode.latency));
    expect(binding.platformDispatcher.requests, <DartPerformanceMode>[DartPerformanceMode.latency]);

    requestHandle1?.dispose();
    expect(binding.debugGetRequestedPerformanceMode(), isNull);
    expect(binding.platformDispatcher.requests, <DartPerformanceMode>[
      DartPerformanceMode.latency,
      DartPerformanceMode.balanced,
    ]);
  });

  test('PerformanceModeHandler revert only after last requestor disposed', () async {
    final PerformanceModeRequestHandle? requestHandle1 = binding.requestPerformanceMode(
      DartPerformanceMode.latency,
    );
    expect(requestHandle1, isNotNull);

    expect(binding.debugGetRequestedPerformanceMode(), equals(DartPerformanceMode.latency));

    final PerformanceModeRequestHandle? requestHandle2 = binding.requestPerformanceMode(
      DartPerformanceMode.latency,
    );
    expect(requestHandle2, isNotNull);

    expect(binding.debugGetRequestedPerformanceMode(), equals(DartPerformanceMode.latency));
    requestHandle1?.dispose();
    expect(binding.debugGetRequestedPerformanceMode(), equals(DartPerformanceMode.latency));
    requestHandle2?.dispose();
    expect(binding.debugGetRequestedPerformanceMode(), isNull);
    expect(binding.platformDispatcher.requests, <DartPerformanceMode>[
      DartPerformanceMode.latency,
      DartPerformanceMode.balanced,
    ]);
  });

  test('PerformanceModeRequestHandle dispatches memory events', () async {
    await expectLater(
      await memoryEvents(
        () => binding.requestPerformanceMode(DartPerformanceMode.latency)!.dispose(),
        PerformanceModeRequestHandle,
      ),
      areCreateAndDispose,
    );
  });
}
