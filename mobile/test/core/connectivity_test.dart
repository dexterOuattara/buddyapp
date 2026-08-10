import 'package:buddywize/core/connectivity.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes loopback API addresses used by a USB reverse tunnel', () {
    expect(
      ConnectivityService.usesLoopbackApi('http://localhost:7878/api'),
      isTrue,
    );
    expect(
      ConnectivityService.usesLoopbackApi('http://127.0.0.1:7878/api'),
      isTrue,
    );
    expect(
      ConnectivityService.usesLoopbackApi('https://api.buddywize.app'),
      isFalse,
    );
  });

  test(
    'uses API reachability when Android reports no network interface',
    () async {
      var probes = 0;

      final online = await ConnectivityService.checkOnline(
        networkCheck: () async => const [ConnectivityResult.none],
        apiProbe: () async {
          probes += 1;
          return true;
        },
      );

      expect(online, isTrue);
      expect(probes, 1);
    },
  );
}
