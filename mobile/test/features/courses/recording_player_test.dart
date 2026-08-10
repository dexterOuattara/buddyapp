import 'package:buddywize/features/recording/recording_player_screen.dart';
import 'package:buddywize/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats recording playback positions', () {
    expect(formatPlaybackTime(Duration.zero), '00:00');
    expect(formatPlaybackTime(const Duration(seconds: 65)), '01:05');
    expect(
      formatPlaybackTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '01:02:03',
    );
  });

  test('sizes the transcript viewport without reserving empty space', () {
    expect(transcriptViewportHeight(0), 84);
    expect(transcriptViewportHeight(1), 84);
    expect(transcriptViewportHeight(2), 160);
    expect(transcriptViewportHeight(20), 228);
  });

  test('parses and selects synchronized transcript cues', () {
    final cues = parseTranscriptSegments('''[
      {"start_ms": 3000, "end_ms": 5000, "text": "Deuxième phrase"},
      {"start_ms": 0, "end_ms": 2500, "text": "Première phrase"}
    ]''');

    expect(cues, hasLength(2));
    expect(cues.first.text, 'Première phrase');
    expect(cues.first.words.map((word) => word.text), ['Première', 'phrase']);
    expect(cues.first.words.last.endMs, 2500);
    expect(activeTranscriptSegmentIndex(cues, Duration.zero), 0);
    expect(
      activeTranscriptSegmentIndex(cues, const Duration(milliseconds: 3500)),
      1,
    );
  });

  test('preserves provider word timestamps and tracks the active word', () {
    final cue = parseTranscriptSegments('''[
      {
        "start_ms": 0,
        "end_ms": 2000,
        "text": "Bonjour le monde",
        "words": [
          {"start_ms": 0, "end_ms": 650, "text": "Bonjour"},
          {"start_ms": 650, "end_ms": 900, "text": "le"},
          {"start_ms": 900, "end_ms": 2000, "text": "monde"}
        ]
      }
    ]''').single;

    expect(cue.words, hasLength(3));
    expect(cue.words[1].startMs, 650);
    expect(activeTranscriptWordIndex(cue, Duration.zero), 0);
    expect(
      activeTranscriptWordIndex(cue, const Duration(milliseconds: 700)),
      1,
    );
    expect(
      activeTranscriptWordIndex(cue, const Duration(milliseconds: 1200)),
      2,
    );
    expect(
      activeTranscriptWordIndex(cue, const Duration(milliseconds: 2000)),
      -1,
    );
  });

  test('splits long segments so the active word remains visible', () {
    final cue = TranscriptCue(
      startMs: 0,
      endMs: 1900,
      text: List.generate(19, (index) => 'mot$index').join(' '),
      words: List.generate(
        19,
        (index) => TranscriptWordCue(
          startMs: index * 100,
          endMs: (index + 1) * 100,
          text: 'mot$index',
        ),
      ),
    );

    final chunks = splitTranscriptCueForDisplay(cue);

    expect(chunks.map((chunk) => chunk.words.length), [8, 8, 3]);
    expect(chunks[1].startMs, 800);
    expect(chunks.last.endMs, 1900);
    expect(
      activeTranscriptSegmentIndex(chunks, const Duration(milliseconds: 1650)),
      2,
    );
    expect(
      activeTranscriptWordIndex(
        chunks.last,
        const Duration(milliseconds: 1650),
      ),
      0,
    );
  });

  test('ignores malformed transcript cues', () {
    final cues = parseTranscriptSegments('''[
      {"start_ms": 500, "end_ms": 100, "text": "invalide"},
      {"start_ms": 0, "end_ms": 100, "text": ""}
    ]''');
    expect(cues, isEmpty);
    expect(activeTranscriptSegmentIndex(cues, Duration.zero), -1);
  });

  test('only marks non-empty transcript rows as available', () {
    final empty = Transcript(
      id: 1,
      serverId: 'empty',
      recordingServerId: 'recording',
      recordingClientUuid: 'local',
      content: '   ',
      language: null,
      segmentsJson: '[]',
      syncVersion: 1,
    );
    final legacy = Transcript(
      id: 2,
      serverId: 'legacy',
      recordingServerId: 'recording',
      recordingClientUuid: 'local-legacy',
      content: 'Texte conservé',
      language: null,
      segmentsJson: '[]',
      syncVersion: 2,
    );

    expect(transcriptIsAvailable(null), isFalse);
    expect(transcriptIsAvailable(empty), isFalse);
    expect(transcriptIsAvailable(legacy), isTrue);
  });
}
