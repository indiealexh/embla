#!/usr/bin/env dart

import 'dart:isolate';
import 'dart:io';
import 'dart:async';

main(List<String> arguments) async {
  if (arguments.length < 1) return print('Usage: embla start');
  final command = arguments[0];
  if (command != 'start') return print('Usage: embla start (Only the run command available currently)');

  final filePath = '${Directory.current.path}/bin/server.dart';
  final fileUri = new Uri.file(filePath);
  bool willRestart = true;
  SendPort restartPort;
  StreamController changeBroadcast = new StreamController.broadcast();

  final watcher = Directory.current.watch(recursive: true).listen((event) {
    if (!event.path.endsWith('.dart')) return;

    changeBroadcast.add(event);
    willRestart = true;
    restartPort?.send(null);
  });

  while (willRestart) {
    willRestart = false;
    final exitPort = new ReceivePort();
    final errorPort = new ReceivePort();
    final receiveExitCommandPort = new ReceivePort();
    await Isolate.spawnUri(
        fileUri,
        [],
        receiveExitCommandPort.sendPort,
        onExit: exitPort.sendPort,
        onError: errorPort.sendPort,
        errorsAreFatal: false,
        automaticPackageResolution: true
    );

    restartPort = await receiveExitCommandPort.first
        .timeout(const Duration(seconds: 10));

    final process = new Completer<int>();
    errorPort.listen((List l) async {
      print(l[0]);
      print('Listening for changes...');
      await changeBroadcast.stream.first;
      if (!process.isCompleted) process.complete(0);
    });
    exitPort.listen((_) {
      if (!process.isCompleted) process.complete(0);
    });

    exitCode = await process.future;
    exitPort.close();
    errorPort.close();
    receiveExitCommandPort.close();
  }

  await watcher.cancel();
}
