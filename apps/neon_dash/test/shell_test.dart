import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_dash/src/audio/cue_player.dart';
import 'package:neon_dash/src/shell/app_shell.dart';
import 'package:neon_dash/src/shell/game_surface.dart';
import 'package:neon_dash/src/shell/haptics.dart';
import 'package:neon_dash/src/shell/home_screen.dart';
import 'package:neon_dash/src/shell/loading_screen.dart';
import 'package:neon_dash/src/shell/menu_screen.dart';
import 'package:neon_dash/src/shell/result_overlay.dart';
import 'package:neon_dash/src/ui/neon_widgets.dart';
import 'package:neon_dash/src/ui/skin_preview.dart';
import 'package:neon_dash/src/storage/profile_store.dart';
import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';

void main() {
  group('The title screen', () {
    testWidgets('opens on the way in rather than on the catalogue',
        (tester) async {
      await _pumpHome(tester, Progression());

      expect(find.text('FLY'), findsOneWidget);
      expect(find.text('LOCKED'), findsNothing);
    });

    testWidgets('names the level the button would fly', (tester) async {
      await _pumpHome(tester, Progression());

      expect(find.text(LevelCatalogue.byIndex(0).name), findsOneWidget);
    });

    testWidgets('flies the first level that is open and not cleared',
        (tester) async {
      LevelDefinition? flown;
      RunMode? mode;
      await _pumpHome(
        tester,
        Progression(),
        onFly: (level) {
          flown = level;
          mode = RunMode.fixed;
        },
      );

      await tester.tap(find.text('FLY'));
      await tester.pump();

      expect(flown?.index, 0);
      expect(mode, RunMode.fixed);
    });

    testWidgets('the hangar is one tap away', (tester) async {
      var opened = false;
      await _pumpHome(tester, Progression(), onOpenMenu: () => opened = true);

      await tester.tap(find.text('HANGAR'));
      await tester.pump();

      expect(opened, isTrue);
    });
  });

  group('Dragging is not tapping', () {
    testWidgets('a drag across a level card starts nothing', (tester) async {
      var started = 0;
      await _pumpMenu(tester, Progression(), onPlay: (_, __) => started++);
      await _settle(tester);

      await tester.drag(
        find.text(LevelCatalogue.byIndex(0).tagline),
        const Offset(0.0, -220.0),
      );
      await tester.pump();

      expect(started, 0);
    });

    testWidgets('a tap on a level card still starts it', (tester) async {
      var started = 0;
      await _pumpMenu(tester, Progression(), onPlay: (_, __) => started++);
      await _settle(tester);

      await tester.tap(find.text(LevelCatalogue.byIndex(0).tagline));
      await tester.pump();

      expect(started, 1);
    });

    testWidgets('a flick sideways moves to the next tab', (tester) async {
      await _pumpMenu(tester, Progression());
      await _settle(tester);

      expect(find.byType(SkinPreview), findsNothing);

      await tester.fling(
        find.text(LevelCatalogue.byIndex(0).tagline),
        const Offset(-300.0, 0.0),
        1200.0,
      );
      await _settle(tester);

      expect(find.byType(SkinPreview), findsWidgets);
    });

    testWidgets('a flick back returns to the level list', (tester) async {
      await _pumpMenu(tester, Progression());
      await _settle(tester);

      await tester.fling(
        find.text(LevelCatalogue.byIndex(0).tagline),
        const Offset(-300.0, 0.0),
        1200.0,
      );
      await _settle(tester);

      await tester.fling(
        find.byType(SkinPreview).first,
        const Offset(300.0, 0.0),
        1200.0,
      );
      await _settle(tester);

      expect(find.text(LevelCatalogue.byIndex(0).tagline), findsOneWidget);
    });

    testWidgets('a flick past the last tab stays put', (tester) async {
      await _pumpMenu(tester, Progression());
      await _settle(tester);

      await tester.fling(
        find.text(LevelCatalogue.byIndex(0).tagline),
        const Offset(300.0, 0.0),
        1200.0,
      );
      await _settle(tester);

      expect(find.text(LevelCatalogue.byIndex(0).tagline), findsOneWidget);
    });
  });

  group('MenuScreen', () {
    testWidgets('a fresh profile opens exactly one level', (tester) async {
      await _pumpMenu(tester, Progression());

      expect(find.text(LevelCatalogue.byIndex(0).tagline), findsOneWidget);
      expect(find.text('LOCKED'), findsNWidgets(LevelCatalogue.count - 1));
    });

    testWidgets('a locked level says what it is waiting for', (tester) async {
      await _pumpMenu(tester, Progression());

      expect(
        find.text('CLEAR ${LevelCatalogue.byIndex(0).name}'),
        findsOneWidget,
      );
      expect(find.textContaining('MORE STARS'), findsWidgets);
    });

    testWidgets('a locked level withholds its name', (tester) async {
      await _pumpMenu(tester, Progression());

      for (var i = 1; i < LevelCatalogue.count; i++) {
        final level = LevelCatalogue.byIndex(i);
        expect(
          find.text(level.tagline),
          findsNothing,
          reason: '${level.name} should still be a mystery',
        );
      }
    });

    testWidgets('tapping an open level starts it', (tester) async {
      LevelDefinition? started;
      await _pumpMenu(tester, Progression(), onPlay: (l, _) => started = l);

      await tester.tap(find.text(LevelCatalogue.byIndex(0).tagline));
      await tester.pump();

      expect(started?.index, 0);
    });

    testWidgets('tapping a locked level does nothing', (tester) async {
      var started = 0;
      await _pumpMenu(tester, Progression(), onPlay: (_, __) => started++);

      await tester.tap(find.text('LOCKED').first);
      await tester.pump();

      expect(started, 0);
    });

    testWidgets('clearing a level opens the next one', (tester) async {
      final profile = Progression()..record(0, 1);
      await _pumpMenu(tester, profile);

      expect(find.text(LevelCatalogue.byIndex(1).name), findsOneWidget);
      expect(find.text('LOCKED'), findsNWidgets(LevelCatalogue.count - 2));
    });

    testWidgets('the header counts stars and shards', (tester) async {
      final profile = Progression(shards: 410)
        ..record(0, 3)
        ..record(1, 2);

      await _pumpMenu(tester, profile);

      expect(find.text('5'), findsOneWidget);
      expect(find.text('410'), findsOneWidget);
    });
  });

  group('Two ways into a level', () {
    testWidgets('a level never cleared offers only the fixed run',
        (tester) async {
      await _pumpMenu(tester, Progression());

      expect(find.text(RunMode.shifting.title), findsNothing);
    });

    testWidgets('clearing a level opens its shifting variant', (tester) async {
      await _pumpMenu(tester, Progression()..record(0, 1));

      expect(find.text(RunMode.shifting.title), findsOneWidget);
    });

    testWidgets('the card body starts the fixed run', (tester) async {
      RunMode? started;
      await _pumpMenu(
        tester,
        Progression()..record(0, 2),
        onPlay: (_, mode) => started = mode,
      );

      await tester.tap(find.text(LevelCatalogue.byIndex(0).tagline));
      await tester.pump();

      expect(started, RunMode.fixed);
    });

    testWidgets('the chip starts the shifting run', (tester) async {
      LevelDefinition? level;
      RunMode? started;
      await _pumpMenu(
        tester,
        Progression()..record(0, 2),
        onPlay: (chosen, mode) {
          level = chosen;
          started = mode;
        },
      );

      await tester.tap(find.text(RunMode.shifting.title));
      await tester.pump();

      expect(started, RunMode.shifting);
      expect(level?.index, 0, reason: 'and the level it sat on');
    });

    testWidgets('an unplayed shifting variant advertises its payout',
        (tester) async {
      await _pumpMenu(tester, Progression()..record(0, 1));

      expect(find.text('x1.5 SHARDS'), findsOneWidget);
    });

    testWidgets('a played shifting variant shows its own record',
        (tester) async {
      final profile = Progression()
        ..record(0, 1)
        ..recordScore(0, 1111)
        ..recordScore(0, 2222, mode: RunMode.shifting);

      await _pumpMenu(tester, profile);

      expect(find.text('2222'), findsOneWidget, reason: 'the shifting best');
      expect(find.text('1111'), findsOneWidget, reason: 'the fixed best');
    });
  });

  group('Settings', () {
    testWidgets('the screen shows what there is to change', (tester) async {
      await _pumpMenu(tester, Progression());
      await _openTab(tester, 'SETTINGS');

      for (final label in <String>['MUSIC', 'EFFECTS', 'VIBRATION']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.byType(NeonSlider), findsNWidgets(2));
      expect(find.byType(NeonToggle), findsOneWidget);
    });

    testWidgets('dragging a slider changes the setting and reports it',
        (tester) async {
      final settings = Settings();
      var saves = 0;
      await _pumpMenu(
        tester,
        Progression(),
        settings: settings,
        onSettingsChanged: () => saves++,
      );
      await _openTab(tester, 'SETTINGS');

      final track = tester.getRect(find.byType(NeonSlider).first);
      await tester.tapAt(Offset(track.left + 2.0, track.center.dy));
      await _settle(tester);

      expect(settings.musicVolume, 0.0);
      expect(saves, greaterThan(0), reason: 'applied and written at once');
      expect(find.text('SOUND IS OFF'), findsNothing,
          reason: 'the effects are still up');
    });

    testWidgets('turning both down says so', (tester) async {
      final settings = Settings(musicVolume: 0.0, effectsVolume: 0.0);
      await _pumpMenu(tester, Progression(), settings: settings);
      await _openTab(tester, 'SETTINGS');

      expect(find.text('SOUND IS OFF'), findsOneWidget);
    });

    testWidgets('the vibration switch flips', (tester) async {
      final settings = Settings();
      await _pumpMenu(tester, Progression(), settings: settings);
      await _openTab(tester, 'SETTINGS');

      await tester.tap(find.byType(NeonToggle));
      await _settle(tester);

      expect(settings.vibration, isFalse);
    });
  });

  group('Haptics', () {
    test('nothing buzzes when it is switched off', () {
      final haptics = Haptics(enabled: false);

      for (final event in GameEvent.values) {
        haptics.onEvent(event);
      }
      haptics.tap();
    });

    test('the events that happen constantly are left alone', () {
      const quiet = <GameEvent>[
        GameEvent.nearMiss,
        GameEvent.orbCollected,
        GameEvent.runStarted,
        GameEvent.portalEnded,
      ];

      expect(quiet.length, lessThan(GameEvent.values.length));
      for (final event in quiet) {
        expect(GameEvent.values, contains(event));
      }
    });
  });

  group('The hull shop', () {
    testWidgets('every hull is listed, with a preview that flies', (
      tester,
    ) async {
      await _pumpMenu(tester, Progression(shards: 2000));
      await _openTab(tester, 'HULLS');

      for (final skin in CraftSkin.values) {
        expect(find.text(skin.title), findsOneWidget, reason: skin.name);
      }
      expect(find.byType(SkinPreview), findsNWidgets(CraftSkin.values.length));
    });

    testWidgets('the hull in use says so and is not for sale', (tester) async {
      await _pumpMenu(tester, Progression(shards: 2000));
      await _openTab(tester, 'HULLS');

      expect(find.text('IN USE'), findsOneWidget);
      expect(find.text('SHARDS'), findsNWidgets(CraftSkin.values.length - 1));
    });

    testWidgets('buying a hull spends the shards and wears it', (tester) async {
      final profile = Progression(shards: 2000);
      var saves = 0;
      await _pumpMenu(tester, profile, onProfileChanged: () => saves++);
      await _openTab(tester, 'HULLS');

      await tester.tap(find.text('${CraftSkin.lance.price}'));
      await _settle(tester);

      expect(profile.ownsSkin(CraftSkin.lance), isTrue);
      expect(profile.selectedSkin, CraftSkin.lance);
      expect(profile.shards, 2000 - CraftSkin.lance.price);
      expect(saves, 1);
    });

    testWidgets('a hull nobody can afford does not sell', (tester) async {
      final profile = Progression();
      await _pumpMenu(tester, profile);
      await _openTab(tester, 'HULLS');

      await tester.tap(find.text('${CraftSkin.prism.price}'));
      await _settle(tester);

      expect(profile.ownsSkin(CraftSkin.prism), isFalse);
    });

    testWidgets('an owned hull can be worn again for nothing', (tester) async {
      final profile = Progression(shards: 2000)
        ..buySkin(CraftSkin.kite)
        ..selectSkin(CraftSkin.standard);
      final left = profile.shards;

      await _pumpMenu(tester, profile);
      await _openTab(tester, 'HULLS');
      await tester.ensureVisible(find.text('WEAR'));
      await _settle(tester);
      await tester.tap(find.text('WEAR'));
      await _settle(tester);

      expect(profile.selectedSkin, CraftSkin.kite);
      expect(profile.shards, left);
    });
  });

  group('Awards', () {
    testWidgets('every award is listed with its target', (tester) async {
      await _pumpMenu(tester, Progression());
      await _openTab(tester, 'AWARDS');

      for (final achievement in Achievement.values) {
        expect(find.text(achievement.title), findsOneWidget,
            reason: achievement.name);
      }
    });

    testWidgets('a fresh profile has earned none of them', (tester) async {
      await _pumpMenu(tester, Progression());
      await _openTab(tester, 'AWARDS');

      expect(
        find.text('0 OF ${Achievement.values.length} EARNED'),
        findsOneWidget,
      );
      expect(find.text('0/1'), findsWidgets, reason: 'the one-run awards');
    });

    testWidgets('progress is shown against the target', (tester) async {
      final profile = Progression();
      for (var i = 0; i < 12; i++) {
        profile.countRun(orbs: 0);
      }

      await _pumpMenu(tester, profile);
      await _openTab(tester, 'AWARDS');

      expect(find.text('12/25'), findsOneWidget, reason: 'runs towards 25');
      expect(find.text('1/1'), findsWidgets, reason: 'the first run, earned');
    });

    testWidgets('the earned count tracks the profile', (tester) async {
      final profile = Progression()
        ..countRun(orbs: 60, finished: true, stars: 3);

      await _pumpMenu(tester, profile);
      await _openTab(tester, 'AWARDS');

      expect(
        find.text('${profile.earnedAchievementCount} OF '
            '${Achievement.values.length} EARNED'),
        findsOneWidget,
      );
      expect(profile.earnedAchievementCount, greaterThan(0));
    });
  });

  group('Hull stats on the card', () {
    testWidgets('every hull shows all four axes', (tester) async {
      await _pumpMenu(tester, Progression());
      await _openTab(tester, 'HULLS');

      for (final label in <String>['SPEED', 'GRIP', 'LOW PROFILE', 'HAUL']) {
        expect(
          find.text(label),
          findsNWidgets(CraftSkin.values.length),
          reason: label,
        );
      }
    });

    testWidgets('every hull has a preview of its own', (tester) async {
      await _pumpMenu(tester, Progression());
      await _openTab(tester, 'HULLS');

      final previews = tester
          .widgetList<SkinPreview>(find.byType(SkinPreview))
          .map((preview) => preview.skin)
          .toSet();

      expect(previews, CraftSkin.values.toSet());
    });
  });

  group('The shop', () {
    testWidgets('every upgrade is listed with its first price and ranks',
        (tester) async {
      await _pumpMenu(tester, Progression(shards: 100));
      await _openTab(tester, 'UPGRADES');

      for (final upgrade in Upgrade.values) {
        expect(find.text(upgrade.title), findsOneWidget);
        expect(find.text('0/${upgrade.maxRank}'), findsWidgets,
            reason: upgrade.name);
      }
    });

    testWidgets('buying a rank spends the shards and advances the rank',
        (tester) async {
      final profile = Progression(shards: 10000);
      var saves = 0;
      await _pumpMenu(tester, profile, onProfileChanged: () => saves++);
      await _openTab(tester, 'UPGRADES');

      final price = Upgrade.extraSlot.prices.first;
      await tester.tap(find.text('$price'));
      await _settle(tester);

      expect(profile.rankOf(Upgrade.extraSlot), 1);
      expect(profile.shards, 10000 - price);
      expect(saves, 1, reason: 'the shell is told to write the file');
      expect(find.text('MAXED'), findsOneWidget);
    });

    testWidgets('a second rank costs the second price', (tester) async {
      final profile = Progression(shards: 10000);
      await _pumpMenu(tester, profile);
      await _openTab(tester, 'UPGRADES');

      await tester.tap(find.text('${Upgrade.potency.prices[0]}'));
      await _settle(tester);

      expect(profile.rankOf(Upgrade.potency), 1);
      expect(find.text('1/${Upgrade.potency.maxRank}'), findsOneWidget);
      expect(find.text('${Upgrade.potency.prices[1]}'), findsOneWidget);
      expect(find.text('RANK 2'), findsOneWidget);
    });

    testWidgets('an upgrade nobody can afford does not sell', (tester) async {
      final profile = Progression();
      await _pumpMenu(tester, profile);
      await _openTab(tester, 'UPGRADES');

      await tester.tap(find.text('${Upgrade.potency.prices.first}'));
      await _settle(tester);

      expect(profile.owns(Upgrade.potency), isFalse);
      expect(find.text('MAXED'), findsNothing);
    });
  });

  group('The record', () {
    testWidgets('it reports what the profile holds', (tester) async {
      final profile = Progression(shards: 12)
        ..record(0, 3)
        ..recordScore(0, 7421)
        ..countRun(orbs: 9);

      await _pumpMenu(tester, profile);
      await _openTab(tester, 'RECORD');

      expect(find.text('7421'), findsOneWidget, reason: 'best score');
      expect(find.text('1'), findsOneWidget, reason: 'one run');
      expect(find.text('9'), findsOneWidget, reason: 'nine orbs');
      expect(
        find.text('3 / ${LevelCatalogue.count * StarRules.maxPerLevel}'),
        findsOneWidget,
        reason: 'stars out of every star in the game',
      );
      expect(
        find.text('1 / ${LevelCatalogue.count}'),
        findsOneWidget,
        reason: 'one level cleared',
      );
    });
  });

  group('ResultOverlay', () {
    testWidgets('a finish offers the next level', (tester) async {
      await _pumpResult(tester, _summary(finished: true, stars: 2));

      expect(find.text('STAGE CLEAR'), findsOneWidget);
      expect(find.text('NEXT LEVEL'), findsOneWidget);
      expect(find.text('CONTINUE'), findsNothing);
    });

    testWidgets('a crash offers a continue at its price', (tester) async {
      await _pumpResult(
        tester,
        _summary(finished: false, stars: 0),
        shardsHeld: 500,
      );

      expect(find.text('RUN ENDED'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.textContaining('SHARDS'), findsWidgets);
    });

    testWidgets('a continue nobody can afford says so', (tester) async {
      await _pumpResult(
        tester,
        _summary(finished: false, stars: 0),
        shardsHeld: 1,
      );

      expect(find.textContaining('NEEDS'), findsOneWidget);
    });

    testWidgets('a crash with no checkpoint hides the continue', (
      tester,
    ) async {
      await _pumpResult(
        tester,
        _summary(finished: false, stars: 0),
        canContinue: false,
      );

      expect(find.text('CONTINUE'), findsNothing);
      expect(find.text('TRY AGAIN'), findsOneWidget);
    });

    testWidgets('the last level offers no next', (tester) async {
      await _pumpResult(
        tester,
        _summary(finished: true, stars: 3),
        onNext: null,
      );

      expect(find.text('NEXT LEVEL'), findsNothing);
      expect(find.text('REPLAY'), findsOneWidget);
    });

    testWidgets('every button reports a press', (tester) async {
      var retried = 0;
      var menu = 0;
      await _pumpResult(
        tester,
        _summary(finished: false, stars: 0),
        onRetry: () => retried++,
        onMenu: () => menu++,
      );

      await tester.tap(find.text('TRY AGAIN'));
      await tester.tap(find.text('MENU'));
      await tester.pump();

      expect(retried, 1);
      expect(menu, 1);
    });
  });

  group('GameSurface', () {
    testWidgets('a crash raises the result screen', (tester) async {
      await _pumpGame(tester, Progression());

      await _flyUntilItEnds(tester);

      expect(find.text('RUN ENDED'), findsOneWidget);
    });

    testWidgets('a crash is not banked while it can still be continued', (
      tester,
    ) async {
      final settled = <RunSummary>[];
      await _pumpGame(tester, Progression(), onRunSettled: settled.add);

      await _flyUntilItEnds(tester);

      expect(settled, isEmpty);
    });

    testWidgets('leaving the result screen banks the run once', (tester) async {
      final settled = <RunSummary>[];
      await _pumpGame(tester, Progression(), onRunSettled: settled.add);
      await _flyUntilItEnds(tester);

      await tester.tap(find.text('TRY AGAIN'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(settled.length, 1);
      expect(settled.single.finished, isFalse);
    });

    testWidgets('a second crash is a second run, not a second payment', (
      tester,
    ) async {
      final settled = <RunSummary>[];
      await _pumpGame(tester, Progression(), onRunSettled: settled.add);

      await _flyUntilItEnds(tester);
      await tester.tap(find.text('TRY AGAIN'));
      await tester.pump(const Duration(milliseconds: 300));
      await _flyUntilItEnds(tester);
      await tester.tap(find.text('TRY AGAIN'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(settled.length, 2);
    });

    testWidgets('the menu button banks the run and leaves', (tester) async {
      final settled = <RunSummary>[];
      var left = 0;
      await _pumpGame(
        tester,
        Progression(),
        onRunSettled: settled.add,
        onExitToMenu: () => left++,
      );
      await _flyUntilItEnds(tester);

      await tester.tap(find.text('MENU'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(settled.length, 1);
      expect(left, 1);
    });

    testWidgets('a continue nobody can pay for changes nothing', (
      tester,
    ) async {
      final profile = Progression();
      await _pumpGame(tester, profile);
      await _flyUntilItEnds(tester);

      if (find.text('CONTINUE').evaluate().isNotEmpty) {
        await tester.tap(find.text('CONTINUE'));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(profile.shards, 0);
      expect(find.text('RUN ENDED'), findsOneWidget);
    });
  });

  group('LoadingScreen', () {
    testWidgets('it shows the title and what it is doing', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: LoadingScreen(
            title: 'NEON DASH',
            caption: 'SYNTHESISING THE SOUNDTRACK',
            progress: 0.4,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('NEON DASH'), findsOneWidget);
      expect(find.text('SYNTHESISING THE SOUNDTRACK'), findsOneWidget);
    });

    testWidgets('it keeps animating without rebuilding its caption', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: LoadingScreen(
            title: 'DEEP SIGNAL',
            caption: 'SCORING',
            progress: 0.0,
          ),
        ),
      );

      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
    });
  });

  group('Audio handed to an isolate', () {
    test('a level soundtrack renders off the main thread', () async {
      final bytes = await renderMusicVoice(LevelCatalogue.byIndex(2).music);

      expect(bytes, hasLength(MusicLayer.values.length));
      for (final layer in bytes) {
        expect(layer.length, greaterThan(44), reason: 'more than a header');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('the boot banks render off the main thread', () async {
      final rendered = renderBootAudio();

      expect(rendered.cues, hasLength(SoundCue.values.length));
      expect(rendered.music, hasLength(MusicLayer.values.length));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('ProfileStore', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('neon_dash_profile');
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    test('nothing saved reads as a fresh profile', () async {
      final store = ProfileStore(directory: directory);

      final profile = await store.load();

      expect(profile.totalStars, 0);
      expect(profile.shards, 0);
    });

    test('a saved profile comes back', () async {
      final store = ProfileStore(directory: directory);
      final saved = Progression(shards: 77)
        ..record(2, 3)
        ..buy(Upgrade.extraSlot);

      await store.save(saved);
      await store.flush();
      final loaded = await ProfileStore(directory: directory).load();

      expect(loaded.shards, saved.shards);
      expect(loaded.starsFor(2), 3);
    });

    test('a half-written file does not reset the player to nothing', () async {
      File('${directory.path}${Platform.pathSeparator}progress.json')
          .writeAsStringSync('{"stars":{"1":2},"shar');

      final loaded = await ProfileStore(directory: directory).load();

      expect(loaded.totalStars, 0, reason: 'unparseable, so a fresh profile');
      expect(loaded.shards, 0);
    });

    test('overlapping saves do not interleave', () async {
      final store = ProfileStore(directory: directory);

      for (var i = 1; i <= 5; i++) {
        unawaited(store.save(Progression(shards: i * 10)));
      }
      await store.flush();

      final loaded = await ProfileStore(directory: directory).load();
      expect(loaded.shards, 50, reason: 'the last write wins, whole');
    });

    test('no scratch file is left behind', () async {
      final store = ProfileStore(directory: directory);

      await store.save(Progression(shards: 3));
      await store.flush();

      final leftovers = directory
          .listSync()
          .where((entry) => entry.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    });
  });
}

Future<void> _pumpMenu(
  WidgetTester tester,
  Progression profile, {
  void Function(LevelDefinition level, RunMode mode)? onPlay,
  VoidCallback? onProfileChanged,
  Settings? settings,
  VoidCallback? onSettingsChanged,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(900.0, 1200.0)),
        child: MenuScreen(
          progression: profile,
          onPlay: onPlay ?? (_, __) {},
          onProfileChanged: onProfileChanged ?? () {},
          settings: settings ?? Settings(),
          onSettingsChanged: onSettingsChanged ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpHome(
  WidgetTester tester,
  Progression profile, {
  ValueChanged<LevelDefinition>? onFly,
  VoidCallback? onOpenMenu,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(900.0, 1200.0)),
        child: HomeScreen(
          progression: profile,
          onFly: onFly ?? (_) {},
          onOpenMenu: onOpenMenu ?? () {},
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _pumpResult(
  WidgetTester tester,
  RunSummary summary, {
  int shardsHeld = 200,
  bool canContinue = true,
  VoidCallback? onRetry,
  VoidCallback? onMenu,
  VoidCallback? onNext = _noop,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(500.0, 900.0)),
        child: ResultOverlay(
          summary: summary,
          level: LevelCatalogue.byIndex(summary.levelIndex),
          starsAlreadyHeld: 0,
          shardsHeld: shardsHeld,
          canContinue: canContinue,
          onContinue: () {},
          onRetry: onRetry ?? () {},
          onMenu: onMenu ?? () {},
          onNext: onNext,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _noop() {}

RunSummary _summary({
  required bool finished,
  required int stars,
  RunMode mode = RunMode.fixed,
}) => RunSummary(
  levelIndex: 1,
  mode: mode,
  finished: finished,
  score: 1234,
  orbs: 8,
  nearMisses: 5,
  hits: finished ? 0 : 1,
  progress: finished ? 1.0 : 0.47,
  checkpointsPassed: 2,
  continuesUsed: 0,
  bonusesSpent: 3,
  stars: stars,
  shards: 33,
);

Future<void> _pumpGame(
  WidgetTester tester,
  Progression profile, {
  ValueChanged<RunSummary>? onRunSettled,
  VoidCallback? onExitToMenu,
  VoidCallback? onProfileChanged,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(480.0, 960.0)),
        child: GameSurface(
          level: LevelCatalogue.byIndex(0),
          mode: RunMode.fixed,
          layoutSeed: null,
          audio: const SilentCuePlayer(),
          haptics: Haptics(enabled: false),
          progression: profile,
          onProfileChanged: onProfileChanged ?? () {},
          onRunSettled: onRunSettled ?? (_) {},
          onExitToMenu: onExitToMenu ?? () {},
          onPlayLevel: (_, __) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _flyUntilItEnds(WidgetTester tester) async {
  await tester.tapAt(const Offset(240.0, 480.0));

  const frame = Duration(milliseconds: 16);
  for (var i = 0; i < 1200; i++) {
    await tester.pump(frame);
    if (find.text('RUN ENDED').evaluate().isNotEmpty) return;
  }
  fail('the craft survived twenty unattended seconds');
}
