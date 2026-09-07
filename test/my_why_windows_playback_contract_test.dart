import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows My Why voice bypasses audioplayers_windows', () {
    final source = File('lib/widgets/my_why_section.dart').readAsStringSync();

    expect(source, contains('Platform.isWindows ? null : AudioPlayer()'));
    expect(source, contains('_playVoiceOnWindows(recording)'));
    expect(source, contains('media_kit.Player'));
    expect(source, contains('Media(Uri.file(path).toString())'));
    expect(source, contains('DeviceFileSource('));
  });

  test('temporary voice diagnostics are removed', () {
    final source = File('lib/widgets/my_why_section.dart').readAsStringSync();

    expect(source, isNot(contains('voice diagnostic')));
    expect(source, isNot(contains('_audioContainerSignature')));
    expect(source, isNot(contains('decrypted file exists=')));
  });
}
