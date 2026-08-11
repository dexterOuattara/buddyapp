import 'package:buddywize/features/recording/recorder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  test('speech capture profile remains AAC-LC 48 kbps 16 kHz mono', () {
    expect(speechRecordingConfig.encoder, AudioEncoder.aacLc);
    expect(speechRecordingConfig.bitRate, 48000);
    expect(speechRecordingConfig.sampleRate, 16000);
    expect(speechRecordingConfig.numChannels, 1);
  });
}
