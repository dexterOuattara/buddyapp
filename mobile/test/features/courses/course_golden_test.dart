import 'dart:convert';

import 'package:buddywize/core/app_theme.dart';
import 'package:buddywize/db/app_database.dart';
import 'package:buddywize/features/courses/course_recording_screen.dart';
import 'package:buddywize/features/courses/courses_screen.dart';
import 'package:buddywize/features/study/study_screen.dart';
import 'package:buddywize/providers.dart';
import 'package:buddywize/sync/sync_engine.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const goldenSize = Size(390, 844);
  late AppDatabase db;
  late Course course;
  late Chapter chapter;
  late Recording recording;
  late QuizAttempt attempt;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.courses)
        .insert(
          CoursesCompanion.insert(
            clientUuid: 'course-maths',
            title: 'Mathématiques',
            description: const Value('Algèbre et géométrie'),
            pendingSync: const Value(false),
          ),
        );
    await db
        .into(db.lessons)
        .insert(
          LessonsCompanion.insert(
            clientUuid: 'lesson-algebra',
            courseClientUuid: 'course-maths',
            title: 'Algèbre linéaire',
            pendingSync: const Value(false),
          ),
        );
    const titles = [
      'Introduction aux vecteurs',
      'Matrices',
      'Systèmes linéaires',
      'Espaces vectoriels',
    ];
    for (var index = 0; index < titles.length; index++) {
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              clientUuid: 'chapter-$index',
              lessonClientUuid: 'lesson-algebra',
              title: titles[index],
              position: Value(index),
              pendingSync: const Value(false),
            ),
          );
    }
    await db
        .into(db.recordings)
        .insert(
          RecordingsCompanion.insert(
            clientUuid: 'recording-vector',
            chapterClientUuid: 'chapter-3',
            localPath: '/tmp/vector.m4a',
            fileName: const Value('cours-10-aout.m4a'),
            durationSecs: const Value(2304),
            status: const Value('processing'),
            uploadedBytes: const Value(640),
            pipelineStage: const Value('transcribing'),
            progressPercent: const Value(58),
            stageCurrent: const Value(1),
            stageTotal: const Value(3),
            statusMessage: const Value('Transcription audio 1/3'),
            createdAt: Value(DateTime(2026, 8, 10, 10, 30)),
          ),
        );
    await db
        .into(db.summaries)
        .insert(
          SummariesCompanion.insert(
            serverId: const Value('summary-server'),
            chapterClientUuid: 'chapter-3',
            contentMd: '''
# Espaces vectoriels

- Un espace vectoriel est un ensemble muni d'additions et de multiplications par un scalaire.
- Les sous-espaces vectoriels sont fermés pour l'addition et la multiplication scalaire.
- Une base est une famille libre génératrice.

La dimension mesure le nombre minimal de directions indépendantes nécessaires pour exprimer les vecteurs.
''',
            structuredJson: Value(
              jsonEncode({
                'key_points': [
                  "Un espace vectoriel combine addition et multiplication par un scalaire.",
                  'Un sous-espace reste fermé pour ces deux opérations.',
                  'Une base est une famille libre et génératrice.',
                ],
                'takeaway':
                    "La dimension mesure le nombre minimal de directions indépendantes d'un espace.",
                'flashcards': [
                  {
                    'front': "Qu'est-ce qu'une base ?",
                    'back': 'Une famille libre et génératrice.',
                  },
                  {
                    'front': "Que mesure la dimension ?",
                    'back': 'Le nombre de directions indépendantes.',
                  },
                  {
                    'front': "Quand un ensemble est-il un sous-espace ?",
                    'back':
                        "Lorsqu'il est fermé pour les opérations vectorielles.",
                  },
                ],
              }),
            ),
            status: const Value('approved'),
            syncVersion: const Value(10),
          ),
        );
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            chapterClientUuid: 'chapter-3',
            itemsJson: jsonEncode([
              {'prompt': 'Vérifier si un ensemble donné est un sous-espace.'},
              {'prompt': "Déterminer une base et la dimension d'un espace."},
              {'prompt': 'Exprimer un vecteur comme combinaison linéaire.'},
            ]),
            status: const Value('approved'),
          ),
        );
    final questions = [
      {
        'prompt': "Qu'est-ce qu'un espace vectoriel ?",
        'topic': 'Espaces vectoriels',
        'choices': [
          'Un ensemble structuré',
          'Un nombre',
          'Une matrice',
          'Une fonction',
        ],
        'correct_index': 0,
        'explanation': 'Il est stable pour les opérations vectorielles.',
      },
      {
        'prompt': 'Que mesure la dimension ?',
        'topic': 'Bases et dimensions',
        'choices': [
          'Les lignes',
          'Les directions indépendantes',
          'Les angles',
          'Les zéros',
        ],
        'correct_index': 1,
      },
      {
        'prompt': "Qu'est-ce qu'une combinaison linéaire ?",
        'topic': 'Combinaisons linéaires',
        'choices': [
          'Une somme pondérée',
          'Un produit simple',
          'Une dérivée',
          'Une norme',
        ],
        'correct_index': 0,
      },
    ];
    await db
        .into(db.quizzes)
        .insert(
          QuizzesCompanion.insert(
            serverId: const Value('quiz-server'),
            chapterClientUuid: 'chapter-3',
            questionsJson: jsonEncode(questions),
            status: const Value('approved'),
            syncVersion: const Value(10),
          ),
        );

    for (final item in const [
      ('attempt-0', 'chapter-0', 8, 10),
      ('attempt-1', 'chapter-1', 8, 10),
      ('attempt-2', 'chapter-2', 5, 10),
    ]) {
      await db
          .into(db.quizAttempts)
          .insert(
            QuizAttemptsCompanion.insert(
              clientUuid: item.$1,
              quizServerId: 'quiz-server-${item.$2}',
              chapterClientUuid: item.$2,
              score: item.$3,
              total: item.$4,
              answersJson: '[]',
              pendingSync: const Value(false),
            ),
          );
    }
    final resultAnswers = [
      {
        'prompt': questions[0]['prompt'],
        'topic': 'Espaces vectoriels',
        'choice': 0,
        'correct': true,
        'correct_index': 0,
        'choices': questions[0]['choices'],
      },
      {
        'prompt': questions[1]['prompt'],
        'topic': 'Bases et dimensions',
        'choice': 0,
        'correct': false,
        'correct_index': 1,
        'choices': questions[1]['choices'],
      },
      {
        'prompt': questions[2]['prompt'],
        'topic': 'Combinaisons linéaires',
        'choice': 0,
        'correct': true,
        'correct_index': 0,
        'choices': questions[2]['choices'],
      },
    ];
    await db
        .into(db.quizAttempts)
        .insert(
          QuizAttemptsCompanion.insert(
            clientUuid: 'attempt-result',
            quizServerId: 'quiz-server',
            chapterClientUuid: 'chapter-3',
            score: 2,
            total: 3,
            answersJson: jsonEncode(resultAnswers),
            pendingSync: const Value(false),
          ),
        );

    course = await db.select(db.courses).getSingle();
    chapter = await (db.select(
      db.chapters,
    )..where((c) => c.clientUuid.equals('chapter-3'))).getSingle();
    recording = await db.select(db.recordings).getSingle();
    attempt = await (db.select(
      db.quizAttempts,
    )..where((a) => a.clientUuid.equals('attempt-result'))).getSingle();
  });

  tearDown(() async => db.close());

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(goldenSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          syncPhaseProvider.overrideWith((ref) => Stream.value(SyncPhase.done)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BuddyTheme.light,
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cleanUpWidget(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.binding.setSurfaceSize(null);
  }

  Widget coursesFrame() => Scaffold(
    appBar: AppBar(title: const Text('Mes cours')),
    body: const CoursesScreen(),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 3,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          label: 'Accueil',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          label: 'Agenda',
        ),
        NavigationDestination(
          icon: Icon(Icons.mic_rounded),
          label: 'Enregistrer',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_rounded),
          label: 'Cours',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      ],
    ),
  );

  testWidgets('courses overview', (tester) async {
    await pumpPage(tester, coursesFrame());
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/courses_1_overview.png'),
    );
    await cleanUpWidget(tester);
  });

  testWidgets('course detail', (tester) async {
    await pumpPage(tester, CourseDetailScreen(course: course));
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/courses_2_course.png'),
    );
    await cleanUpWidget(tester);
  });

  testWidgets('chapter detail', (tester) async {
    await pumpPage(
      tester,
      ChapterDetailScreen(chapter: chapter, courseTitle: course.title),
    );
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/courses_3_chapter.png'),
    );
    await cleanUpWidget(tester);
  });

  testWidgets('ai processing', (tester) async {
    await pumpPage(
      tester,
      CourseProcessingScreen(
        recordingId: recording.id,
        chapter: chapter,
        courseTitle: course.title,
      ),
    );
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/courses_4_processing.png'),
    );
    await cleanUpWidget(tester);
  });

  testWidgets('smart summary', (tester) async {
    await pumpPage(
      tester,
      ChapterStudyView(chapter: chapter, courseTitle: course.title),
    );
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/courses_5_summary.png'),
    );
    await cleanUpWidget(tester);
  });

  testWidgets('quiz result', (tester) async {
    await pumpPage(
      tester,
      QuizResultScreen(
        chapter: chapter,
        courseTitle: course.title,
        attempt: attempt,
      ),
    );
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/courses_6_quiz_result.png'),
    );
    await cleanUpWidget(tester);
  });
}
