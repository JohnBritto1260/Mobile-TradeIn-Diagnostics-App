import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Android Build import
import 'package:flutter/foundation.dart' show kIsWeb, unawaited;

// Define Build.VERSION for Android compatibility
class Build {
  static final VERSION = _Version();
}

class _Version {
  static const int SDK_INT = 23; // Default to Android 6.0 (Marshmallow)
}

// Define VERSION_CODES
class VERSION_CODES {
  static const int M = 23;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase - let it use google-services.json configuration
  try {
    await Firebase.initializeApp();
    
    // Initialize Crashlytics in debug mode
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    
    print('✅ Firebase initialized successfully in main app');
    print('📊 Database URL: ${FirebaseDatabase.instance.databaseURL}');
    print('🔧 Crashlytics enabled');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('📍 Stack trace: ${StackTrace.current}');
    // Continue without Firebase if initialization fails
  }
  
  runApp(const TradeInDiagnosticsApp());
}

class TradeInDiagnosticsApp extends StatelessWidget {
  const TradeInDiagnosticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trade-In Diagnostics',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      home: const DiagnosticsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen>
    with TickerProviderStateMixin {
  bool isRunning = false;
  String deviceInfo = '';
  String deviceId = '';
  int currentTestIndex = -1;
  double progress = 0.0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Method channel for native communication
  static const platform = MethodChannel('trade_In.Internal_Data/diagnostics');

  final List<Map<String, dynamic>> testList = [
    {'name': 'Speaker', 'icon': Icons.volume_up, 'status': 'Pending', 'instruction': '🔊 Ensure your device volume is up. The app will play a test sound automatically.'},
    {'name': 'Microphone', 'icon': Icons.mic, 'status': 'Pending', 'instruction': '🎤 Please speak clearly into your microphone when prompted. The test will record for 5 seconds.'},
    {'name': 'Vibration', 'icon': Icons.vibration, 'status': 'Pending', 'instruction': '📳 Your device will vibrate briefly. Please hold the device to feel the vibration.'},
    {'name': 'Touchscreen', 'icon': Icons.touch_app, 'status': 'Pending', 'instruction': '👆 Please touch all highlighted boxes on the screen to test touch responsiveness.'},
    {'name': 'Volume Buttons', 'icon': Icons.settings_remote, 'status': 'Pending', 'instruction': '🔊 Please press both Volume UP and Volume DOWN buttons when prompted.'},
    {'name': 'Power Button', 'icon': Icons.power_settings_new, 'status': 'Pending', 'instruction': '🔋 Please press the power button twice: turn screen OFF, then ON, then unlock.'},
    {'name': 'Battery', 'icon': Icons.battery_full, 'status': 'Pending', 'instruction': '🔌 Please connect your charger to the device when prompted for battery health analysis.'},
  ];

  @override
  void initState() {
    super.initState();
    _initApp();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _animationController.forward();
  }

  Future<void> _initApp() async {
    // Request Phone permission immediately to allow fetching Serial Number
    await Permission.phone.request();
    // Then fetch device info
    await _getDeviceInfo();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _getDeviceInfo() async {
    try {
      final Map<dynamic, dynamic> info = await platform.invokeMethod('getDeviceInfo');
      setState(() {
        deviceId = info['deviceId']?.toString() ?? 'Unknown';
        
        final manufacturer = info['manufacturer']?.toString() ?? 'Unknown';
        final model = info['model']?.toString() ?? 'Unknown';
        final product = info['product']?.toString() ?? 'Unknown';
        final serial = info['serial']?.toString() ?? 'Unknown';
        final osVersion = info['osVersion']?.toString() ?? 'Unknown';

        deviceInfo =
            'Manufacturer: $manufacturer\n'
            'Model: $model\n'
            'Product: $product\n'
            'Serial: $serial\n'
            'OS: Android $osVersion\n'
            'Device ID: $deviceId';
      });
    } catch (e) {
      print('Failed to get device info: $e');
      // Fallback to basic info if native call fails
      final info = await DeviceInfoPlugin().androidInfo;
      setState(() {
        deviceId = info.id;
        deviceInfo =
            '${info.manufacturer} ${info.model}\nOS: Android ${info.version.release}\nDevice ID: ${info.id}\n(Basic Info Only)';
      });
    }
  }

  Future<void> _runDiagnostics() async {
    if (isRunning) return;
    
    // Add haptic feedback
    try {
      await Vibration.vibrate(duration: 50);
    } catch (e) {
      // Ignore if vibration is not supported
    }
    
    // Check and request necessary permissions before starting tests
    bool permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      _showPermissionDeniedDialog();
      return;
    }
    
    setState(() {
      isRunning = true;
      progress = 0.0;
      for (var t in testList) t['status'] = 'Pending';
    });

    for (int i = 0; i < testList.length; i++) {
      setState(() {
        currentTestIndex = i;
        progress = (i / testList.length);
      });

      final name = testList[i]['name'];
      await _updateTest(i, 'In Progress');

      String result;
      switch (name) {
        case 'Speaker':
          result = await _testSpeaker();
          break;
        case 'Microphone':
          result = await _testMicrophone();
          break;
        case 'Vibration':
          result = await _testVibration();
          break;
        case 'Touchscreen':
          result = await _testTouchscreen();
          break;
        case 'Volume Buttons':
          result = await _testVolumeButtons();
          break;
        case 'Power Button':
          result = await _testPowerButton();
          break;
        case 'Battery':
          result = await _testBattery();
          break;
        default:
          result = 'Skipped';
      }

      await _updateTest(i, result);
    }

    setState(() {
      isRunning = false;
      progress = 1.0;
      currentTestIndex = -1;
    });

    // Navigate to results page instead of showing dialog
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TestResultsScreen(
        testResults: testList,
        deviceId: deviceId,
        deviceInfo: deviceInfo,
      )),
    );
  }

  // -----------------------------------------------------------------
  // TEST IMPLEMENTATIONS
  // -----------------------------------------------------------------

  Future<String> _testSpeaker() async {
    try {
      // Request audio permissions for speaker test
      var audioStatus = await Permission.microphone.request();
      if (!audioStatus.isGranted) {
        return 'Failed (Audio permission denied)';
      }
      
      // Show dialog to guide user through speaker test
      bool userReady = await _showSpeakerTestDialog();
      if (!userReady) {
        return 'Failed (User cancelled)';
      }
      
      final bool result = await platform.invokeMethod('testSpeaker');
      return result ? 'Passed' : 'Failed (No audio detected)';
    } on PlatformException catch (e) {
      return 'Failed (Error: ${e.message})';
    } catch (e) {
      return 'Failed (Unknown error)';
    }
  }

  Future<String> _testMicrophone() async {
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      return 'Failed (Permission denied)';
    }
    
    try {
      // Navigate to the new microphone test screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MicrophoneTestScreen()),
      );
      
      // Return result based on test completion
      return result == true ? 'Passed' : 'Failed (No audio input detected)';
    } on PlatformException catch (e) {
      return 'Failed (Error: ${e.message})';
    } catch (e) {
      return 'Failed (Unknown error)';
    }
  }

  Future<String> _testVibration() async {
    try {
      final bool result = await platform.invokeMethod('testVibration');
      return result ? 'Passed' : 'Failed (Vibration not supported)';
    } on PlatformException catch (e) {
      return 'Failed (Error: ${e.message})';
    } catch (e) {
      return 'Failed (Unknown error)';
    }
  }

  Future<String> _testTouchscreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TouchScreenTestPage()),
    );
    return result == true ? 'Passed' : 'Failed';
  }

  Future<String> _testVolumeButtons() async {
    const volumeChannel = EventChannel('trade_In.Internal_Data/volume_buttons');
    
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VolumeButtonTestDialog(volumeChannel: volumeChannel),
    );

    return result == true ? 'Passed' : 'Failed (Volume buttons not detected)';
  }

  Future<String> _testPowerButton() async {
    // Set up event channel for power button events
    const powerButtonChannel = EventChannel('trade_In.Internal_Data/power_button');
    StreamSubscription? powerButtonSubscription;
    
    final completer = Completer<bool>();
    bool screenOffDetected = false;
    bool screenOnDetected = false;
    bool userPresentDetected = false;
    int remaining = 30;
    Timer? countdown;
    BuildContext? dialogContext;

    // Listen for power button events
    powerButtonSubscription = powerButtonChannel.receiveBroadcastStream().listen((event) {
      if (!completer.isCompleted) {
        final eventType = event as String;
        print('Power button event received: $eventType');
        
        // Detect screen state changes
        if (eventType == "SCREEN_OFF") {
          screenOffDetected = true;
          print('Screen OFF detected - first power button press');
        } else if (eventType == "SCREEN_ON") {
          screenOnDetected = true;
          print('Screen ON detected - second power button press');
        } else if (eventType == "USER_PRESENT") {
          userPresentDetected = true;
          print('User present detected - device unlocked');
        }
        
        // Check if we detected the complete power button cycle
        if (screenOffDetected && screenOnDetected && userPresentDetected) {
          print('Complete power button cycle detected!');
          completer.complete(true);
          
          // Safe dialog closure using post frame callback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (dialogContext != null && dialogContext!.mounted && Navigator.canPop(dialogContext!)) {
              try {
                Navigator.pop(dialogContext!);
              } catch (e) {
                print('Error closing dialog: $e');
              }
            }
          });
        }
      }
    }, onError: (error) {
      print('Power button event error: $error');
    });

    // Show dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;

        return StatefulBuilder(
          builder: (context, setState) {
            // Start timer only if it hasn't been started yet
            if (countdown == null) {
              countdown = Timer.periodic(const Duration(seconds: 1), (t) {
                if (!completer.isCompleted) {
                  setState(() {
                    remaining--;
                    print('Power button timer tick: $remaining seconds remaining');
                    
                    if (remaining <= 0) {
                      completer.complete(false);
                      t.cancel();
                      powerButtonSubscription?.cancel();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (dialogContext != null && dialogContext!.mounted && Navigator.canPop(dialogContext!)) {
                          try {
                            Navigator.pop(dialogContext!, false);
                          } catch (e) {
                            print('Error closing dialog on timeout: $e');
                          }
                        }
                      });
                    }
                  });
                }
              });
            }

            return AlertDialog(
              title: const Text('Power Button Test'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.power_settings_new, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Press the power button twice:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Press to turn screen OFF\n2. Press again to turn screen ON\n3. Unlock your device',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⏱ $remaining sec remaining',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Status indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Icon(
                            Icons.power_off,
                            size: 24,
                            color: screenOffDetected ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Screen OFF',
                            style: TextStyle(
                              color: screenOffDetected ? Colors.green : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: screenOffDetected ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      
                      Column(
                        children: [
                          Icon(
                            Icons.power,
                            size: 24,
                            color: screenOnDetected ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Screen ON',
                            style: TextStyle(
                              color: screenOnDetected ? Colors.green : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: screenOnDetected ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      
                      Column(
                        children: [
                          Icon(
                            Icons.lock_open,
                            size: 24,
                            color: userPresentDetected ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Unlocked',
                            style: TextStyle(
                              color: userPresentDetected ? Colors.green : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: userPresentDetected ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  if (screenOffDetected && screenOnDetected && userPresentDetected) ...[
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.check_circle,
                      size: 32,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Power button test completed!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (!completer.isCompleted) {
                      completer.complete(false);
                      countdown?.cancel();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Skip Test'),
                ),
              ],
            );
          },
        );
      },
    );

    // Cancel subscription and timer
    powerButtonSubscription.cancel();
    countdown?.cancel();
    
    final result = await completer.future;
    return result ? 'Passed' : 'Failed (timeout)';
  }

  Future<String> _testBattery() async {
    try {
      // Request battery permissions if needed (some devices require this)
      if (_Version.SDK_INT >= VERSION_CODES.M) {
        var status = await Permission.ignoreBatteryOptimizations.request();
        // Continue even if denied, as basic battery info should still work
      }

      // Run the new battery health test
      final bool testResult = await _runBatteryHealthTest();
      
      if (testResult) {
        return 'Passed (Battery health test completed)';
      } else {
        return 'Failed (Battery health test failed or cancelled)';
      }
    } on PlatformException catch (e) {
      return 'Failed (Platform Error: ${e.message ?? "Unknown platform error"})';
    } catch (e) {
      return 'Failed (Error: ${e.toString()})';
    }
  }

  Future<void> _updateTest(int i, String result) async {
    if (!mounted) return;
    setState(() => testList[i]['status'] = result);
    await Future.delayed(const Duration(milliseconds: 150));
  }

  Future<bool> _requestPermissions() async {
    try {
      // Request all necessary permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.phone,
      ].request();

      // Check if all permissions are granted
      bool allGranted = statuses.values.every((status) => status.isGranted);
      
      if (!allGranted) {
        // Check if any permissions are permanently denied
        bool permanentlyDenied = statuses.entries.any((entry) => 
          entry.value.isPermanentlyDenied);
        
        if (permanentlyDenied) {
          _showOpenSettingsDialog();
        }
      }
      
      return allGranted;
    } catch (e) {
      return false;
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.security, size: 48, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'This app requires microphone and vibration permissions to run diagnostics tests.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Please grant the necessary permissions to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestPermissions();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showSpeakerTestDialog() async {
    final completer = Completer<bool>();
    BuildContext? dialogContext;
    late Timer countdown;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;

        // Start the test immediately and close dialog after audio finishes
        Timer(const Duration(milliseconds: 100), () {
          if (!completer.isCompleted) {
            completer.complete(true);
            // Close dialog immediately after starting test
            if (dialogContext != null && dialogContext!.mounted && Navigator.canPop(dialogContext!)) {
              Navigator.pop(dialogContext!);
            }
          }
        });

        // Fallback timer to ensure dialog closes even if something goes wrong
        countdown = Timer(const Duration(seconds: 3), () {
          if (!completer.isCompleted) {
            completer.complete(false);
            if (dialogContext != null && dialogContext!.mounted && Navigator.canPop(dialogContext!)) {
              Navigator.pop(dialogContext!);
            }
          }
        });

        return AlertDialog(
          title: const Text('🔊 Speaker Test'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.volume_up, size: 48, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Testing Speaker...',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Playing test tone through speaker.\nDevice volume automatically increased.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                '🔊 You should hear a clear tone now.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );

    // Cancel fallback timer
    countdown.cancel();
    return completer.future;
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Permissions Permanently Denied'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Some permissions are permanently denied. Please enable them in app settings.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Without these permissions, some diagnostic tests may not work properly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue with Limited Tests'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<bool> _runBatteryHealthTest() async {
    final completer = Completer<bool>();
    BuildContext? dialogContext;
    Timer? chargingCheckTimer;
    Timer? overallTimer;
    int remainingTime = 60; // 60 seconds total test time
    bool chargerConnected = false;
    Map<String, dynamic>? initialBatteryInfo;
    Map<String, dynamic>? currentBatteryInfo;
    String healthAssessment = 'Unknown';
    bool dataFetchFailed = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;

        return StatefulBuilder(
          builder: (context, setState) {
            // Start overall timer only if it hasn't been started yet
            if (overallTimer == null) {
              overallTimer = Timer.periodic(const Duration(seconds: 1), (t) {
                if (!completer.isCompleted) {
                  setState(() {
                    remainingTime--;
                    print('Battery timer tick: $remainingTime seconds remaining');
                    
                    if (remainingTime <= 0) {
                      completer.complete(false);
                      chargingCheckTimer?.cancel();
                      overallTimer?.cancel();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (dialogContext != null && dialogContext!.mounted && Navigator.canPop(dialogContext!)) {
                          try {
                            Navigator.pop(dialogContext!);
                          } catch (e) {
                            print('Error closing dialog on timeout: $e');
                          }
                        }
                      });
                    }
                  });
                }
              });
            }

            // Start charging check timer inside StatefulBuilder so it can update UI properly
            if (chargingCheckTimer == null) {
              chargingCheckTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
                if (!completer.isCompleted) {
                  try {
                    print('=== FLUTTER: Attempting to get battery info ===');
                    
                    // Get current battery info
                    final batteryData = await platform.invokeMethod('getBatteryInfo');
                    
                    print('=== FLUTTER: Battery info received: $batteryData ===');
                    
                    // Convert Map<Object?, Object?> to Map<String, dynamic>
                    if (batteryData != null) {
                      currentBatteryInfo = Map<String, dynamic>.from(batteryData);
                    }
                    
                    // Check if we got valid battery data
                    if (currentBatteryInfo != null && currentBatteryInfo!['level'] != null) {
                      print('=== FLUTTER: Valid battery data detected ===');
                      
                      // Check if charger is connected - more robust detection
                      final isCharging = currentBatteryInfo?['isCharging'] ?? false;
                      final powerSource = currentBatteryInfo?['powerSource'] ?? 'Battery';
                      final status = currentBatteryInfo?['status'] ?? 'Unknown';
                      
                      print('=== FLUTTER: Charging status - isCharging: $isCharging, powerSource: $powerSource, status: $status ===');
                      
                      // Enhanced charger detection - handle 100% battery scenario
                      final isChargerDetected = (powerSource != 'Battery') || 
                                             (status == 'Charging') || 
                                             (status == 'Full') ||
                                             (powerSource == 'USB' && status == 'Discharging'); // Handle 100% battery with USB
                      
                      print('=== FLUTTER: Enhanced charger detection - isChargerDetected: $isChargerDetected ===');
                      
                      if (isChargerDetected) {
                        if (!chargerConnected) {
                          print('=== FLUTTER: Charger connected! ===');
                          // Update UI state when charger is connected
                          setState(() {
                            chargerConnected = true;
                          });
                          
                          // Get initial battery info for comparison
                          if (initialBatteryInfo == null) {
                            initialBatteryInfo = currentBatteryInfo;
                          }
                          
                          // Get health assessment
                          try {
                            print('=== FLUTTER: Getting battery health assessment ===');
                            healthAssessment = await platform.invokeMethod('getBatteryHealthAssessment');
                            print('=== FLUTTER: Health assessment received: $healthAssessment ===');
                          } catch (e) {
                            print('=== FLUTTER: Error getting health assessment: $e ===');
                            healthAssessment = 'Unknown';
                          }
                          
                          // Complete test successfully
                          completer.complete(true);
                          chargingCheckTimer?.cancel();
                          overallTimer?.cancel();
                          
                          // Close dialog first
                          if (dialogContext != null && dialogContext!.mounted && Navigator.canPop(dialogContext!)) {
                            Navigator.pop(dialogContext!);
                          }
                          
                          // Add a small delay to ensure the first dialog is fully dismissed before showing results
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted && currentBatteryInfo != null) {
                              _showBatteryHealthResults(currentBatteryInfo, healthAssessment);
                            }
                          });
                        }
                      } else {
                        print('=== FLUTTER: Charger not connected yet ===');
                      }
                    } else {
                      // Invalid battery data received
                      print('=== FLUTTER: INVALID BATTERY DATA - currentBatteryInfo: $currentBatteryInfo ===');
                      setState(() {
                        dataFetchFailed = true;
                      });
                    }
                  } on PlatformException catch (e) {
                    // If we can't get battery info, mark as data fetch failed
                    print('=== FLUTTER: PLATFORM EXCEPTION - Code: ${e.code}, Message: ${e.message}, Details: ${e.details} ===');
                    setState(() {
                      dataFetchFailed = true;
                    });
                  } catch (e) {
                    // If we can't get battery info, mark as data fetch failed
                    print('=== FLUTTER: GENERAL EXCEPTION - $e ===');
                    setState(() {
                      dataFetchFailed = true;
                    });
                  }
                }
              });
            }

            return AlertDialog(
              title: const Text('🔋 Battery Health Test'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.battery_charging_full, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    '🔌 Please connect your charger',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chargerConnected 
                      ? '✅ Charger connected! Detecting battery health...'
                      : 'Connect your charger to begin battery health test',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: chargerConnected ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.timer,
                          size: 24,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '⏱ $remainingTime sec remaining',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          chargerConnected ? 'Analyzing battery...' : 'Waiting for charger connection',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dataFetchFailed) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '⚠️ Unable to fetch battery data',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (!completer.isCompleted) {
                      completer.complete(false);
                      chargingCheckTimer?.cancel();
                      overallTimer?.cancel();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Cancel Test'),
                ),
              ],
            );
          },
        );
      },
    );


    // Clean up timers
    chargingCheckTimer?.cancel();
    overallTimer?.cancel();
    
    return completer.future;
  }

  void _showBatteryHealthResults(Map<String, dynamic>? batteryInfo, String healthAssessment) {
    // Add null check to prevent showing dialog with invalid data
    if (batteryInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to retrieve battery information'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final level = batteryInfo['level'] ?? 0;
    final voltage = batteryInfo['voltage'] ?? 0; // Already in mV from Android
    final temperature = batteryInfo['temperatureInCelsius'] ?? 0.0;
    final healthPercentage = batteryInfo['healthPercentage'] ?? -1;
    final cycleCount = batteryInfo['cycleCount'] ?? -1;

    // Determine battery condition color
    Color getConditionColor(String assessment) {
      switch (assessment) {
        case 'Excellent': return Colors.green;
        case 'Good': return Colors.lightGreen;
        case 'Fair': return Colors.orange;
        case 'Poor': return Colors.deepOrange;
        case 'Critical': return Colors.red;
        default: return Colors.grey;
      }
    }

    // Ensure the widget is still mounted before showing dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔋 Battery Health Test Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.battery_full, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Charging status ✅',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Battery Health Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (healthPercentage >= 0) ...[
                    _buildHealthInfoRow('Capacity Health', '$healthPercentage%'),
                    const SizedBox(height: 8),
                  ],
                  if (cycleCount >= 0) ...[
                    _buildHealthInfoRow('Cycle Count', '$cycleCount'),
                    const SizedBox(height: 8),
                  ],
                  _buildHealthInfoRow('Voltage', '${voltage} mV'),
                  const SizedBox(height: 8),
                  _buildHealthInfoRow('Temperature', '${temperature.toStringAsFixed(1)} °C'),
                  const SizedBox(height: 16),
                  
                  // Battery Condition
                  Row(
                    children: [
                      const Text(
                        'Battery Condition: ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        healthAssessment,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: getConditionColor(healthAssessment),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.shade50,
              Colors.blue.shade50,
              Colors.white,
              Colors.purple.shade50,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.phone_android,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Device Diagnostics',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Complete hardware testing',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Device Information Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                color: Colors.indigo,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Device Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          deviceInfo,
                          style: TextStyle(
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Progress Section
                  if (isRunning) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _pulseAnimation.value,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.analytics,
                                        color: Colors.indigo,
                                        size: 20,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Running Diagnostics...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.grey[200],
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(
                                    colors: [Colors.indigo, Colors.indigo.shade300],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(progress * 100).toInt()}% Complete',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${currentTestIndex + 1} of ${testList.length}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Current Test Instruction
                  if (isRunning && currentTestIndex >= 0) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _pulseAnimation.value,
                                    child: Icon(
                                      testList[currentTestIndex]['icon'],
                                      color: Colors.indigo,
                                      size: 24,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Testing: ${testList[currentTestIndex]['name']}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            testList[currentTestIndex]['instruction'],
                            style: TextStyle(
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Test Status List
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Test Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: testList.length,
                                itemBuilder: (context, i) {
                                  final t = testList[i];
                                  Widget statusWidget;
                                  Color statusColor;
                                  
                                  if (t['status'].startsWith('Passed')) {
                                    statusWidget = const Icon(Icons.check_circle, color: Colors.green, size: 20);
                                    statusColor = Colors.green;
                                  } else if (t['status'].startsWith('Failed')) {
                                    statusWidget = const Icon(Icons.cancel, color: Colors.red, size: 20);
                                    statusColor = Colors.red;
                                  } else if (t['status'] == 'In Progress') {
                                    statusWidget = SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo),
                                    );
                                    statusColor = Colors.indigo;
                                  } else {
                                    statusWidget = Icon(Icons.circle_outlined, color: Colors.grey[400]!, size: 20);
                                    statusColor = Colors.grey;
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: i == currentTestIndex 
                                          ? Colors.indigo.withOpacity(0.1) 
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: i == currentTestIndex 
                                            ? Colors.indigo.withOpacity(0.3)
                                            : Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          t['icon'],
                                          color: statusColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                t['name'],
                                                style: TextStyle(
                                                  fontWeight: i == currentTestIndex 
                                                      ? FontWeight.bold 
                                                      : FontWeight.normal,
                                                  color: i == currentTestIndex 
                                                      ? Colors.indigo 
                                                      : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                t['status'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        statusWidget,
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action Button
                  if (!isRunning)
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.indigo, Colors.indigo.shade400],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _runDiagnostics,
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow, color: Colors.white, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Start Device Diagnostics',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Test Results Screen
class TestResultsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> testResults;
  final String deviceId;
  final String deviceInfo;

  const TestResultsScreen({
    super.key, 
    required this.testResults,
    required this.deviceId,
    required this.deviceInfo,
  });

  @override
  State<TestResultsScreen> createState() => _TestResultsScreenState();
}

class _TestResultsScreenState extends State<TestResultsScreen> {

  Future<void> _uploadResultsToFirebase() async {
    print('=== DEBUG: Upload Results Button Clicked ===');
    print('=== DEBUG: Device ID: ${widget.deviceId} ===');
    print('=== DEBUG: Device Info: ${widget.deviceInfo} ===');
    print('=== DEBUG: Test Results: ${widget.testResults} ===');
    
    final passed = widget.testResults.where((t) => t['status'].startsWith('Passed')).length;
    final successRate = (passed / widget.testResults.length * 100).toInt();
    
    print('=== DEBUG: Passed: $passed, Success Rate: $successRate% ===');

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Uploading to Firebase...'),
          ],
        ),
      ),
    );

    try {
      print('=== DEBUG: Starting Firebase upload process ===');
      
      // Parse device info to extract manufacturer, model, etc.
      final deviceInfoLines = widget.deviceInfo.split('\n');
      final deviceInfoMap = <String, dynamic>{};
      
      for (final line in deviceInfoLines) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('Manufacturer:')) {
          deviceInfoMap['manufacturer'] = trimmedLine.split('Manufacturer:').last.trim();
        } else if (trimmedLine.startsWith('Model:')) {
          deviceInfoMap['model'] = trimmedLine.split('Model:').last.trim();
        } else if (trimmedLine.startsWith('Product:')) {
          deviceInfoMap['product'] = trimmedLine.split('Product:').last.trim();
        } else if (trimmedLine.startsWith('Serial:')) {
          deviceInfoMap['serial'] = trimmedLine.split('Serial:').last.trim();
        } else if (trimmedLine.startsWith('OS:')) {
          final osLine = trimmedLine.split('OS:').last.trim();
          // Extract just the version number from "Android X.X"
          deviceInfoMap['androidVersion'] = osLine.replaceAll('Android', '').trim();
        } else if (trimmedLine.startsWith('Device ID:')) {
          deviceInfoMap['id'] = trimmedLine.split('Device ID:').last.trim();
        }
      }
      
      // Ensure all required fields exist with fallback values
      deviceInfoMap['manufacturer'] ??= 'Unknown';
      deviceInfoMap['model'] ??= 'Unknown';
      deviceInfoMap['product'] ??= 'Unknown';
      deviceInfoMap['serial'] ??= 'Unknown';
      deviceInfoMap['androidVersion'] ??= 'Unknown';
      deviceInfoMap['id'] ??= widget.deviceId;
      
      print('=== DEBUG: Parsed device info: $deviceInfoMap ===');

      // Upload to Firebase
      print('=== DEBUG: Calling FirebaseDatabaseService.uploadDiagnosticResults ===');
      final success = await FirebaseDatabaseService.uploadDiagnosticResults(
        deviceId: widget.deviceId,
        deviceInfo: deviceInfoMap,
        testResults: widget.testResults,
        overallScore: successRate,
        testDuration: 'Estimated 7 minutes',
      );
      
      print('=== DEBUG: Firebase upload result: $success ===');

      // Close loading dialog
      Navigator.pop(context);

      if (success) {
        print('=== DEBUG: Upload successful, showing success message ===');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Results uploaded successfully to Firebase!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        print('=== DEBUG: Upload failed, showing error message ===');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to upload results to Firebase'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('=== DEBUG: Upload exception caught: $e ===');
      print('=== DEBUG: Exception stack trace: ${StackTrace.current} ===');
      
      // Close loading dialog
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final passed = widget.testResults.where((t) => t['status'].startsWith('Passed')).length;
    final failed = widget.testResults.length - passed;
    final successRate = (passed / widget.testResults.length * 100).toInt();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Test Results',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Success Overview Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        failed == 0 ? Icons.check_circle : Icons.warning,
                        size: 64,
                        color: failed == 0 ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        failed == 0 ? 'All Tests Passed!' : 'Some Tests Failed',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: failed == 0 ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$passed of ${widget.testResults.length} tests successful ($successRate%)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey[200],
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                colors: failed == 0 
                                    ? [Colors.green, Colors.green.shade300]
                                    : [Colors.orange, Colors.orange.shade300],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Detailed Results
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detailed Results',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                              itemCount: widget.testResults.length,
                              itemBuilder: (context, i) {
                                final t = widget.testResults[i];
                                final isPassed = t['status'].startsWith('Passed');
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isPassed 
                                        ? Colors.green.withOpacity(0.1) 
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isPassed 
                                          ? Colors.green.withOpacity(0.3)
                                          : Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        t['icon'],
                                        color: isPassed ? Colors.green : Colors.red,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t['name'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isPassed ? Colors.green : Colors.red,
                                              ),
                                            ),
                                            Text(
                                              t['status'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isPassed ? Icons.check_circle : Icons.cancel,
                                        color: isPassed ? Colors.green : Colors.red,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.pop(context),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.refresh, color: Color(0xFF6B7280)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Reset Test',
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.indigo, Colors.indigo.shade400],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                print('=== DEBUG: Upload Results Button TAPPED ===');
                                _uploadResultsToFirebase();
                              },
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload, color: Colors.white, size: 24),
                                  SizedBox(width: 8),
                                  Text(
                                    'Upload Results',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------- Volume Button Test Dialog -------------------

class _VolumeButtonTestDialog extends StatefulWidget {
  final EventChannel volumeChannel;

  const _VolumeButtonTestDialog({required this.volumeChannel});

  @override
  State<_VolumeButtonTestDialog> createState() => _VolumeButtonTestDialogState();
}

class _VolumeButtonTestDialogState extends State<_VolumeButtonTestDialog> {
  Timer? timer;
  int remaining = 30;
  bool volumeUpPressed = false;
  bool volumeDownPressed = false;
  bool testCompleted = false;
  StreamSubscription? _volumeSubscription;

  @override
  void initState() {
    super.initState();
    
    // Add a small delay to ensure EventChannel is properly initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !testCompleted) {
        // Set up event channel listener for volume button events
        _volumeSubscription = widget.volumeChannel.receiveBroadcastStream().listen((event) {
          if (!testCompleted) {
            setState(() {
              final buttonPressed = event as String;
              if (buttonPressed == "VOLUME_UP") {
                volumeUpPressed = true;
              } else if (buttonPressed == "VOLUME_DOWN") {
                volumeDownPressed = true;
              }
              
              // Check if both buttons are pressed
              if (volumeUpPressed && volumeDownPressed) {
                testCompleted = true;
                // Close dialog immediately
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                });
              }
            });
          }
        }, onError: (error) {
          print('Volume button event error: $error');
        });
      }
    });
    
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!testCompleted) {
        setState(() {
          remaining--;
          if (remaining <= 0) {
            testCompleted = true;
            timer?.cancel();
            _volumeSubscription?.cancel();
            Navigator.pop(context, false);
          }
        });
      }
    });
  }

  void _skipTest() {
    if (!testCompleted) {
      testCompleted = true;
      timer?.cancel();
      _volumeSubscription?.cancel();
      Navigator.pop(context, false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _volumeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Volume Button Test'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volume_up, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Press both Volume UP 🔼 and Volume DOWN 🔽 buttons',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Press both buttons to complete the test',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          
          // Status indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Icon(
                    Icons.volume_up,
                    size: 32,
                    color: volumeUpPressed ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Volume UP',
                    style: TextStyle(
                      color: volumeUpPressed ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: volumeUpPressed ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              
              Column(
                children: [
                  Icon(
                    Icons.volume_down,
                    size: 32,
                    color: volumeDownPressed ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Volume DOWN',
                    style: TextStyle(
                      color: volumeDownPressed ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: volumeDownPressed ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Timer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '⏱ $remaining sec remaining',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          
          if (volumeUpPressed && volumeDownPressed && !testCompleted) ...[
            const SizedBox(height: 16),
            const Icon(
              Icons.check_circle,
              size: 32,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            const Text(
              'Both buttons detected!',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _skipTest,
          child: const Text('Skip Test'),
        ),
      ],
    );
  }
}

// ------------------- Touchscreen Test -------------------

class TouchScreenTestPage extends StatefulWidget {
  @override
  State<TouchScreenTestPage> createState() => _TouchScreenTestPageState();
}

class _TouchScreenTestPageState extends State<TouchScreenTestPage> {
  // Dynamic grid calculation based on screen size
  late int rows;
  late int cols;
  late List<List<bool>> touched;
  late List<Rect> gridRects;
  
  Timer? timer;
  int timeLeft = 30;
  bool done = false;

  bool get allTouched => touched.every((r) => r.every((c) => c));

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => timeLeft--);
      if (timeLeft <= 0) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateGrid();
  }

  void _calculateGrid() {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;
    
    // Get actual available screen size (no app bar - full screen)
    final screenWidth = mediaQuery.size.width - padding.left - padding.right;
    final screenHeight = mediaQuery.size.height - padding.top - padding.bottom;
    
    // Calculate grid to cover full screen with reasonable cell size
    const minCellSize = 60.0; // Minimum cell size for touchability
    const maxCellSize = 100.0; // Maximum cell size for good coverage
    
    // Calculate optimal cell size and grid dimensions
    final cellSizeWidth = screenWidth / (screenWidth / minCellSize).ceil();
    final cellSizeHeight = screenHeight / (screenHeight / minCellSize).ceil();
    final cellSize = math.min(cellSizeWidth, cellSizeHeight).clamp(minCellSize, maxCellSize);
    
    cols = (screenWidth / cellSize).floor();
    rows = (screenHeight / cellSize).floor();
    
    // Ensure minimum grid size
    cols = math.max(cols, 6);
    rows = math.max(rows, 8);
    
    // Initialize touched array and grid rectangles
    touched = List.generate(rows, (_) => List.filled(cols, false));
    gridRects = [];
    
    // Calculate actual cell size based on final grid dimensions
    final actualCellWidth = screenWidth / cols;
    final actualCellHeight = screenHeight / rows;
    
    // Store grid cell rectangles for accurate touch detection
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        gridRects.add(Rect.fromLTWH(
          col * actualCellWidth,
          row * actualCellHeight,
          actualCellWidth,
          actualCellHeight,
        ));
      }
    }
  }

  void _finish() {
    if (done) return;
    done = true;
    timer?.cancel();
    Navigator.pop(context, allTouched);
  }

  void _touch(Offset pos) {
    // Find which grid cell was touched
    for (int i = 0; i < gridRects.length; i++) {
      if (gridRects[i].contains(pos)) {
        final row = i ~/ cols;
        final col = i % cols;
        
        setState(() {
          touched[row][col] = true;
        });
        
        if (allTouched) {
          _finish();
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;

    // Use full available screen area (no app bar)
    final screenWidth = mediaQuery.size.width - padding.left - padding.right;
    final screenHeight = mediaQuery.size.height - padding.top - padding.bottom;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onPanDown: (d) => _touch(d.localPosition),
          onPanUpdate: (d) => _touch(d.localPosition),
          child: Container(
            width: screenWidth,
            height: screenHeight,
            color: Colors.black12,
            child: Stack(
              children: [
                // Full screen grid that covers entire available area
                Positioned.fill(
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows * cols,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: screenWidth / cols / (screenHeight / rows),
                      mainAxisSpacing: 1.0,
                      crossAxisSpacing: 1.0,
                    ),
                    itemBuilder: (context, i) {
                      final r = i ~/ cols;
                      final c = i % cols;
                      return Container(
                        decoration: BoxDecoration(
                          color: touched[r][c]
                              ? Colors.green
                              : Colors.grey[300],
                          border: Border.all(
                            color: Colors.grey[700]!,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Center(
                          child: Text(
                            '${r * cols + c + 1}',
                            style: TextStyle(
                              color: touched[r][c]
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: math.min(screenWidth / cols, screenHeight / rows) * 0.15,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Timer and instructions overlay
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '⏱ $timeLeft sec remaining',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Touch all $rows×$cols boxes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Full screen coverage',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Test completion overlay
                if (done)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.8),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              allTouched
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: allTouched
                                  ? Colors.green
                                  : Colors.red,
                              size: 100,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              allTouched
                                  ? 'Test Passed!'
                                  : 'Test Failed',
                              style: TextStyle(
                                color: allTouched
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tested $rows×$cols grid (${rows * cols} points)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}

// -------------------------------------------------------------
// NEW MICROPHONE TEST SCREEN
// -------------------------------------------------------------

/// Example home page that can navigate to the microphone test
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Diagnostics')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MicrophoneTestScreen(),
              ),
            );
          },
          icon: const Icon(Icons.mic),
          label: const Text("Test Microphone"),
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------
/// MICROPHONE TEST SCREEN
/// -------------------------------------------------------------
class MicrophoneTestScreen extends StatefulWidget {
  const MicrophoneTestScreen({super.key});

  @override
  State<MicrophoneTestScreen> createState() => _MicrophoneTestScreenState();
}

class _MicrophoneTestScreenState extends State<MicrophoneTestScreen> {
  static const platform =
      MethodChannel('trade_In.Internal_Data/audio');
  static const amplitudeChannel =
      EventChannel('trade_In.Internal_Data/audio_amplitude');

  bool? testPassed;
  bool isTesting = false;
  int remainingSeconds = 5;
  Timer? _timer;
  List<double> amplitudes = [];
  StreamSubscription? _amplitudeSubscription;

  /// Starts the full 5-second microphone test
  Future<void> _runMicrophoneTest() async {
    setState(() {
      isTesting = true;
      testPassed = null;
      remainingSeconds = 5;
      amplitudes.clear();
    });

    // Countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 1) {
        setState(() => remainingSeconds--);
      } else {
        timer.cancel();
      }
    });

    // Start streaming amplitude for waveform
    unawaited(_startAmplitudeStream());

    try {
      final result = await platform.invokeMethod('testMicrophone');
      setState(() {
        testPassed = result == true;
      });
    } on PlatformException catch (e) {
      debugPrint("Error during mic test: ${e.message}");
      setState(() => testPassed = false);
    } finally {
      _timer?.cancel();
      setState(() => isTesting = false);
    }
  }

  /// Starts real-time amplitude streaming from Android
  Future<void> _startAmplitudeStream() async {
    _amplitudeSubscription = amplitudeChannel
        .receiveBroadcastStream()
        .listen((amplitude) {
          if (amplitude != null && amplitude >= 0) {
            setState(() {
              amplitudes.add(amplitude);
              // Keep only the last 100 amplitude values for performance
              if (amplitudes.length > 100) {
                amplitudes.removeAt(0);
              }
            });
          }
        }, onError: (error) {
          debugPrint("Error in amplitude stream: $error");
        });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Microphone Test")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isTesting) ...[
                Text(
                  "Speak for $remainingSeconds seconds",
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomPaint(
                    painter: WaveformPainter(amplitudes),
                  ),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                const Text("Listening..."),
              ] else if (testPassed != null) ...[
                Icon(
                  testPassed! ? Icons.check_circle : Icons.error,
                  color: testPassed! ? Colors.green : Colors.red,
                  size: 80,
                ),
                const SizedBox(height: 16),
                Text(
                  testPassed!
                      ? "Microphone works correctly!"
                      : "No sound detected or microphone issue.",
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retest"),
                        onPressed: _runMicrophoneTest,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text("Done"),
                        onPressed: () {
                          Navigator.pop(context, testPassed);
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Icon(Icons.mic_none, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  "Press below to start microphone test",
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _runMicrophoneTest,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Start Test"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------
/// WAVEFORM VISUALIZATION
/// -------------------------------------------------------------
class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  WaveformPainter(this.amplitudes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (amplitudes.isNotEmpty) {
      for (int i = 0; i < amplitudes.length; i++) {
        final x = (i / amplitudes.length) * size.width;
        final normalized = (amplitudes[i] / 2000.0).clamp(-1.0, 1.0);
        final y = size.height / 2 - normalized * (size.height / 2);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    // Slight shadow effect for depth
    final shadowPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.2)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      oldDelegate.amplitudes != amplitudes;
}
