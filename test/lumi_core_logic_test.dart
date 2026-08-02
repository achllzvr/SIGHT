import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/services/api_config_service.dart';
import 'package:lumi/services/detection_service.dart';
import 'package:lumi/screens/media_hub_screen.dart';

void main() {
  group('DetectionService distance formula', () {
    final detection = DetectionService.instance;

    test('triangle similarity: calibration / faceWidth', () {
      expect(detection.calculateDistance(faceWidthPixels: 100, calibrationData: 4000), 40.0);
      expect(detection.calculateDistance(faceWidthPixels: 200, calibrationData: 4000), 20.0);
    });

    test('zero face width returns 0', () {
      expect(detection.calculateDistance(faceWidthPixels: 0, calibrationData: 4000), 0.0);
    });
  });

  group('DetectionService blink FSM', () {
    final detection = DetectionService.instance;

    test('closed then open counts as one blink', () {
      expect(detection.detectBlink(currentEAR: 0.40, baselineEAR: 0.52), isFalse);
      expect(detection.detectBlink(currentEAR: 0.70, baselineEAR: 0.52), isTrue);
    });

    test('open while already open is not a blink', () {
      detection.detectBlink(currentEAR: 0.70, baselineEAR: 0.52);
      expect(detection.detectBlink(currentEAR: 0.80, baselineEAR: 0.52), isFalse);
    });
  });

  group('ApiConfigService sync paths (D1)', () {
    test('batch metrics endpoint is child-scoped', () {
      expect(
        ApiConfigService.metricsBatchEndpoint(42),
        '/api/mobile/child/42/sync/metrics/batch',
      );
      expect(
        ApiConfigService.petSyncEndpoint(7),
        '/api/mobile/child/7/sync/pet',
      );
      expect(
        ApiConfigService.sessionLimitsEndpoint(3),
        '/api/mobile/child/3/sync/limits',
      );
    });
  });

  group('Watch Area allowlist (M3)', () {
    test('allows YouTube family hosts', () {
      expect(isAllowedWatchUrl('https://www.youtube.com/watch?v=1'), isTrue);
      expect(isAllowedWatchUrl('https://www.youtubekids.com/'), isTrue);
      expect(isAllowedWatchUrl('https://www.youtube.com/playables'), isTrue);
      expect(isAllowedWatchUrl('https://m.youtube.com'), isTrue);
    });

    test('blocks DRM streamers and non-http', () {
      expect(isAllowedWatchUrl('https://www.netflix.com'), isFalse);
      expect(isAllowedWatchUrl('https://www.tiktok.com'), isFalse);
      expect(isAllowedWatchUrl('intent://foo'), isFalse);
    });
  });
}
