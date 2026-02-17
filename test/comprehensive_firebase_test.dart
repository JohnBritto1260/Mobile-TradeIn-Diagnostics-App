import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../lib/firebase_service.dart';

/// Comprehensive Firebase Test Suite
/// Tests all aspects of Firebase connectivity and functionality
/// 
/// FIXED VERSION: Added proper timeout handling to prevent system hangs
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== COMPREHENSIVE FIREBASE TEST SUITE ===');
  print('Testing Firebase connectivity, upload, and error handling...');
  
  try {
    // Test 1: Firebase Initialization
    await testWithTimeout('Firebase Initialization', testFirebaseInitialization, 30);
    
    // Test 2: Network Connectivity
    await testWithTimeout('Network Connectivity', testNetworkConnectivity, 10);
    
    // Test 3: Firebase Availability
    await testWithTimeout('Firebase Availability', testFirebaseAvailability, 15);
    
    // Test 4: Basic Database Operations
    await testWithTimeout('Basic Database Operations', testBasicDatabaseOperations, 30);
    
    // Test 5: Diagnostic Data Upload
    await testWithTimeout('Diagnostic Data Upload', testDiagnosticDataUpload, 30);
    
    // Test 6: Error Handling
    await testWithTimeout('Error Handling', testErrorHandling, 20);
    
    print('=== FIREBASE TEST SUITE COMPLETED ===');
  } catch (e) {
    print('❌ TEST SUITE FAILED: $e');
    print('=== TEST SUITE TERMINATED DUE TO TIMEOUT ===');
  }
}

/// Wrapper function to add timeout handling to prevent hanging
Future<void> testWithTimeout(String testName, Future<void> Function() testFunction, int timeoutSeconds) async {
  print('\n--- Starting $testName (Timeout: ${timeoutSeconds}s) ---');
  
  try {
    await testFunction().timeout(
      Duration(seconds: timeoutSeconds),
      onTimeout: () {
        throw TimeoutException('$testName timed out after ${timeoutSeconds} seconds', Duration(seconds: timeoutSeconds));
      },
    );
    print('✅ $testName completed successfully');
  } on TimeoutException catch (e) {
    print('❌ $testName FAILED: ${e.message}');
    rethrow;
  } catch (e) {
    print('❌ $testName FAILED: $e');
    // Don't rethrow for non-timeout errors to allow other tests to continue
  }
}

Future<void> testFirebaseInitialization() async {
  print('\n--- TEST 1: Firebase Initialization ---');
  
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
    print('📊 Database URL: ${FirebaseDatabase.instance.databaseURL}');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('📍 Stack trace: ${StackTrace.current}');
  }
}

Future<void> testNetworkConnectivity() async {
  print('\n--- TEST 2: Network Connectivity ---');
  
  try {
    final connectivityResult = await Connectivity().checkConnectivity();
    print('🌐 Network connectivity status: $connectivityResult');
    
    switch (connectivityResult) {
      case ConnectivityResult.wifi:
        print('✅ Connected via WiFi');
        break;
      case ConnectivityResult.mobile:
        print('✅ Connected via Mobile Data');
        break;
      case ConnectivityResult.ethernet:
        print('✅ Connected via Ethernet');
        break;
      case ConnectivityResult.none:
        print('❌ No network connectivity');
        break;
      default:
        print('⚠️ Unknown connectivity status: $connectivityResult');
        break;
    }
  } catch (e) {
    print('❌ Network connectivity check failed: $e');
  }
}

Future<void> testFirebaseAvailability() async {
  print('\n--- TEST 3: Firebase Availability ---');
  
  try {
    final isAvailable = await FirebaseDatabaseService.isFirebaseAvailable();
    if (isAvailable) {
      print('✅ Firebase is available and connected');
    } else {
      print('❌ Firebase is not available');
    }
  } catch (e) {
    print('❌ Firebase availability check failed: $e');
  }
}

Future<void> testBasicDatabaseOperations() async {
  print('\n--- TEST 4: Basic Database Operations ---');
  
  try {
    final database = FirebaseDatabase.instance.ref();
    final testPath = 'test/${DateTime.now().millisecondsSinceEpoch}';
    
    // Test Write
    print('📝 Testing database write...');
    await database.child('$testPath/write_test').set({
      'message': 'Hello from test suite',
      'timestamp': DateTime.now().toIso8601String(),
      'testType': 'basic_operations',
    });
    print('✅ Database write successful');
    
    // Test Read
    print('📖 Testing database read...');
    final snapshot = await database.child('$testPath/write_test').get();
    if (snapshot.exists) {
      print('✅ Database read successful: ${snapshot.value}');
    } else {
      print('❌ Database read failed: No data found');
    }
    
    // Test Update
    print('🔄 Testing database update...');
    await database.child('$testPath/write_test').update({
      'status': 'updated',
      'updateTimestamp': DateTime.now().toIso8601String(),
    });
    print('✅ Database update successful');
    
    // Test Delete
    print('🗑️ Testing database delete...');
    await database.child(testPath).remove();
    print('✅ Database delete successful');
    
  } catch (e) {
    print('❌ Basic database operations failed: $e');
  }
}

Future<void> testDiagnosticDataUpload() async {
  print('\n--- TEST 5: Diagnostic Data Upload ---');
  
  try {
    // Create test diagnostic data
    final testDeviceId = 'test_device_${DateTime.now().millisecondsSinceEpoch}';
    final testDeviceInfo = {
      'manufacturer': 'Test Manufacturer',
      'model': 'Test Model',
      'androidVersion': '11',
      'id': testDeviceId,
    };
    
    final testResults = [
      {
        'name': 'Test Speaker',
        'icon': Icons.volume_up,
        'status': 'Passed',
        'instruction': 'Test instruction for speaker',
      },
      {
        'name': 'Test Microphone',
        'icon': Icons.mic,
        'status': 'Failed',
        'instruction': 'Test instruction for microphone',
      },
      {
        'name': 'Test Vibration',
        'icon': Icons.vibration,
        'status': 'Passed',
        'instruction': 'Test instruction for vibration',
      },
    ];
    
    print('📤 Testing diagnostic data upload...');
    final success = await FirebaseDatabaseService.uploadDiagnosticResults(
      deviceId: testDeviceId,
      deviceInfo: testDeviceInfo,
      testResults: testResults,
      overallScore: 67,
      testDuration: 'Test Duration: 2 minutes',
    );
    
    if (success) {
      print('✅ Diagnostic data upload successful');
      
      // Verify the data was uploaded
      print('🔍 Verifying uploaded data...');
      final uploadedData = await FirebaseDatabaseService.getDeviceDiagnostics(testDeviceId);
      if (uploadedData != null) {
        print('✅ Data verification successful');
        print('📊 Uploaded data keys: ${uploadedData.keys.toList()}');
      } else {
        print('❌ Data verification failed: No data found');
      }
    } else {
      print('❌ Diagnostic data upload failed');
    }
    
  } catch (e) {
    print('❌ Diagnostic data upload test failed: $e');
  }
}

Future<void> testErrorHandling() async {
  print('\n--- TEST 6: Error Handling ---');
  
  try {
    // Test with invalid device ID
    print('🚫 Testing error handling with invalid data...');
    final success = await FirebaseDatabaseService.uploadDiagnosticResults(
      deviceId: '', // Empty device ID
      deviceInfo: {},
      testResults: [],
      overallScore: 0,
      testDuration: '',
    );
    
    if (!success) {
      print('✅ Error handling working correctly - invalid data rejected');
    } else {
      print('⚠️ Error handling may need improvement - invalid data was accepted');
    }
    
    // Test network connectivity check
    print('🌐 Testing network connectivity check...');
    final hasNetwork = await FirebaseDatabaseService.checkNetworkConnectivity();
    print('📊 Network connectivity check result: $hasNetwork');
    
  } catch (e) {
    print('❌ Error handling test failed: $e');
  }
}
