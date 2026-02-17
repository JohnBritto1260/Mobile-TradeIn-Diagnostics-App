import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('trade_In.Internal_Data/diagnostics');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getDeviceInfo') {
        return {
          'deviceId': 'test_device_id',
          'manufacturer': 'Samsung',
          'model': 'SM-S901B',
          'product': 'Galaxy S22',
          'serial': 'R5C...',
          'osVersion': '13',
        };
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getDeviceInfo returns expected map', () async {
    final Map<dynamic, dynamic>? result = await channel.invokeMethod('getDeviceInfo');
    
    expect(result, isNotNull);
    expect(result!['product'], 'Galaxy S22');
    expect(result['serial'], 'R5C...');
    expect(result['model'], 'SM-S901B');
  });
}
