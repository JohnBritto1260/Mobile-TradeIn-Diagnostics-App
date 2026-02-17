import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Enhanced logging helper with consistent tagging
void _log(String message, {String level = 'INFO'}) {
  final timestamp = DateTime.now().toIso8601String();
  final tag = 'FIREBASE_SERVICE';
  final formattedMessage = '[$timestamp] [$level] [$tag] $message';
  
  // Use print() for logcat visibility (works on Android)
  print(formattedMessage);
  
  // Also use developer.log for debugging
  developer.log(message, name: tag);
}

class FirebaseDatabaseService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static const String _diagnosticsPath = 'analytics';

  /// Initialize Firebase (call this in main() or before using Firebase)
  /// Initialize Firebase (call this in main() or before using Firebase)
  static Future<void> initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        // Manual initialization - replace placeholders with your Firebase credentials
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "YOUR_API_KEY_HERE",
            appId: "YOUR_APP_ID_HERE",
            messagingSenderId: "YOUR_MESSAGING_SENDER_ID_HERE",
            projectId: "YOUR_PROJECT_ID_HERE",
            databaseURL: "YOUR_DATABASE_URL_HERE",
          ),
        );
        _log('Firebase initialized with manual options (placeholders)');
      } else {
        _log('Firebase already initialized');
      }
      _log('Database URL: ${FirebaseDatabase.instance.databaseURL}');
    } catch (e) {
      _log('Firebase initialization failed: $e');
      _log('Stack trace: ${StackTrace.current}');
      // Don't rethrow, just log, so app can continue (maybe offline)
    }
  }

  /// Upload diagnostic test results to Firebase Realtime Database
  /// 
  /// [deviceId] - Unique device identifier (Android device ID)
  /// [deviceInfo] - Device information dictionary
  /// [testResults] - List of test results with status and details
  /// [overallScore] - Overall test success percentage
  /// [testDuration] - Total time taken for tests
  static Future<bool> uploadDiagnosticResults({
    required String deviceId,
    required Map<String, dynamic> deviceInfo,
    required List<Map<String, dynamic>> testResults,
    required int overallScore,
    required String testDuration,
  }) async {
    try {
      _log('=== FIREBASE UPLOAD START ===');
      _log('Device ID: $deviceId');
      _log('Database URL: ${FirebaseDatabase.instance.databaseURL}');
      _log('Diagnostics Path: $_diagnosticsPath');
      

      // Ensure Firebase is initialized
      await initializeFirebase();

      // Temporarily skip Firebase availability check as it's causing "Invalid token in path" error
      // The error occurs when trying to read .info/connected
      // We'll proceed directly to upload and let it fail gracefully if Firebase is unavailable
      /*
      final isAvailable = await isFirebaseAvailable();
      if (!isAvailable) {
        _log('Firebase is not available');
        return false;
      }
      */
      _log('Skipping Firebase availability check, proceeding with upload');

      // Create test entry with timestamp
      final timestamp = DateTime.now().toIso8601String();
      final testKey = 'test_${timestamp.replaceAll(RegExp(r'[:.-]'), '')}';
      
      _log('Test Key: $testKey');
      _log('Timestamp: $timestamp');

      // Sanitize deviceId to remove invalid Firebase path characters
      // Firebase paths cannot contain: . $ # [ ] /
      final sanitizedDeviceId = deviceId.replaceAll(RegExp(r'[.$#\[\]/]'), '_');
      _log('Original Device ID: $deviceId');
      _log('Sanitized Device ID: $sanitizedDeviceId');

      // Prepare diagnostic data
      final diagnosticData = {
        'deviceId': sanitizedDeviceId,  // Use sanitized ID
        'timestamp': timestamp,
        'deviceInfo': deviceInfo,
        'testResults': testResults.map((test) => {
          'name': test['name'],
          'status': test['status'],
          'icon': test['icon'].toString(),
          'instruction': test['instruction'] ?? '',
        }).toList(),
        'overallScore': overallScore,
        'testDuration': testDuration,
        'passedTests': testResults.where((t) => t['status'].toString().startsWith('Passed')).length,
        'failedTests': testResults.where((t) => t['status'].toString().startsWith('Failed')).length,
        'totalTests': testResults.length,
      };

      _log('Diagnostic Data Prepared: ${diagnosticData.keys.toList()}');

      // Upload to Firebase under sanitized device ID
      final deviceRef = _database.child('$_diagnosticsPath/$sanitizedDeviceId');
      final fullPath = '$_diagnosticsPath/$sanitizedDeviceId';
      
      _log('Upload Path: $fullPath');
      
      // Try a simple write first to test connectivity
      await deviceRef.child('connectivity_test').set({
        'test': 'connection',
        'timestamp': timestamp,
      }).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          _log('Connectivity test write timed out', level: 'ERROR');
          throw TimeoutException('Connectivity test write timed out', Duration(seconds: 15));
        },
      );
      
      _log('Connectivity test passed');

      // Update device info and add test history
      // First update the device-level fields
      await deviceRef.update({
        'deviceId': deviceId,
        'lastTest': timestamp,
        'deviceInfo': deviceInfo,
        'latestScore': overallScore,
      }).timeout(
        Duration(seconds: 25),
        onTimeout: () {
          _log('Firebase upload operation timed out', level: 'ERROR');
          throw TimeoutException('Firebase upload operation timed out', Duration(seconds: 25));
        },
      );
      
      // Then add the test history entry separately to avoid path issues
      await deviceRef.child('testHistory').child(testKey).set(diagnosticData).timeout(
        Duration(seconds: 25),
        onTimeout: () {
          _log('Firebase test history upload timed out', level: 'ERROR');
          throw TimeoutException('Firebase test history upload timed out', Duration(seconds: 25));
        },
      );

      _log('=== FIREBASE UPLOAD SUCCESS ===');
      _log('Data uploaded to: $fullPath');
      return true;
    } catch (e) {
      _log('=== FIREBASE UPLOAD FAILED ===');
      _log('Error: $e');
      _log('Error Type: ${e.runtimeType}');
      _log('Stack Trace: ${StackTrace.current}');
      
      // Try to get more specific error information
      if (e.toString().contains('permission-denied')) {
        _log('PERMISSION ERROR: Check Firebase Realtime Database rules');
      } else if (e.toString().contains('network')) {
        _log('NETWORK ERROR: Check internet connection');
      } else if (e.toString().contains('database')) {
        _log('DATABASE ERROR: Check Firebase project configuration');
      }
      
      return false;
    }
  }

  /// Get all diagnostic results for a specific device
  static Future<Map<String, dynamic>?> getDeviceDiagnostics(String deviceId) async {
    try {
      final snapshot = await _database.child('$_diagnosticsPath/$deviceId').get().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          _log('Get device diagnostics timed out for: $deviceId', level: 'ERROR');
          throw TimeoutException('Get device diagnostics timed out', Duration(seconds: 15));
        },
      );
      
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } on TimeoutException catch (e) {
      _log('Device diagnostics retrieval timed out: ${e.message}', level: 'ERROR');
      return null;
    } catch (e) {
      developer.log('Failed to get device diagnostics: $e');
      return null;
    }
  }

  /// Get the latest test result for a device
  static Future<Map<String, dynamic>?> getLatestTestResult(String deviceId) async {
    try {
      final deviceData = await getDeviceDiagnostics(deviceId);
      if (deviceData != null && deviceData.containsKey('testHistory')) {
        final testHistory = Map<String, dynamic>.from(deviceData['testHistory']);
        
        // Find the latest test (sort by timestamp)
        String latestTestKey = '';
        DateTime latestTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
        
        for (final entry in testHistory.entries) {
          final testData = Map<String, dynamic>.from(entry.value);
          final testTimestamp = DateTime.parse(testData['timestamp']);
          
          if (testTimestamp.isAfter(latestTimestamp)) {
            latestTimestamp = testTimestamp;
            latestTestKey = entry.key;
          }
        }
        
        if (latestTestKey.isNotEmpty) {
          return Map<String, dynamic>.from(testHistory[latestTestKey]);
        }
      }
      return null;
    } catch (e) {
      developer.log('Failed to get latest test result: $e');
      return null;
    }
  }

  /// Delete all diagnostic data for a device
  static Future<bool> deleteDeviceDiagnostics(String deviceId) async {
    try {
      await _database.child('$_diagnosticsPath/$deviceId').remove().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          _log('Delete device diagnostics timed out for: $deviceId', level: 'ERROR');
          throw TimeoutException('Delete device diagnostics timed out', Duration(seconds: 15));
        },
      );
      developer.log('Device diagnostics deleted for: $deviceId');
      return true;
    } on TimeoutException catch (e) {
      _log('Device diagnostics deletion timed out: ${e.message}', level: 'ERROR');
      return false;
    } catch (e) {
      developer.log('Failed to delete device diagnostics: $e');
      return false;
    }
  }

  /// Check network connectivity before Firebase operations
  static Future<bool> checkNetworkConnectivity() async {
    try {
      // Import connectivity check
      final connectivityResult = await Connectivity().checkConnectivity();
      _log('Network connectivity status: $connectivityResult');
      
      switch (connectivityResult) {
        case ConnectivityResult.wifi:
        case ConnectivityResult.mobile:
        case ConnectivityResult.ethernet:
          return true;
        case ConnectivityResult.none:
          _log('No network connectivity available', level: 'ERROR');
          return false;
        default:
          _log('Unknown connectivity status: $connectivityResult', level: 'ERROR');
          return false;
      }
    } catch (e) {
      _log('Error checking network connectivity: $e', level: 'ERROR');
      return false;
    }
  }

  /// Check if Firebase is available and connected
  static Future<bool> isFirebaseAvailable() async {
    try {
      // First check network connectivity
      final hasNetwork = await checkNetworkConnectivity();
      if (!hasNetwork) {
        return false;
      }

      final database = FirebaseDatabase.instance;
      database.goOnline(); // Ensure we're online
      
      // Test Firebase connectivity with a simple read and timeout
      final testRef = database.ref().child('.info/connected');
      final snapshot = await testRef.get().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          _log('Firebase connectivity check timed out', level: 'ERROR');
          throw TimeoutException('Firebase connectivity check timed out', Duration(seconds: 10));
        },
      );
      
      if (snapshot.exists) {
        final isConnected = snapshot.value as bool? ?? false;
        _log('Firebase connectivity check: $isConnected');
        return isConnected;
      } else {
        _log('Firebase connectivity test failed - no snapshot', level: 'ERROR');
        return false;
      }
    } on TimeoutException catch (e) {
      _log('Firebase availability check timed out: ${e.message}', level: 'ERROR');
      return false;
    } catch (e) {
      _log('Firebase not available: $e', level: 'ERROR');
      return false;
    }
  }

  /// Get database reference for custom queries
  static DatabaseReference get databaseReference => _database;
}
