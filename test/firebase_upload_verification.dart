import 'dart:developer' as developer;
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../lib/firebase_service.dart';

/// Firebase Upload Verification Test
/// 
/// This test specifically focuses on verifying Firebase upload functionality
/// with comprehensive logging and step-by-step verification
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== FIREBASE UPLOAD VERIFICATION TEST ===');
  print('Purpose: Verify Firebase upload functionality with detailed logging');
  print('');
  
  // Create a log file for detailed analysis
  final logFile = File('firebase_upload_log.txt');
  final logSink = logFile.openWrite();
  
  try {
    // Step 1: Initialize Firebase with detailed logging
    await verifyFirebaseInitialization(logSink);
    
    // Step 2: Check network connectivity
    await verifyNetworkConnectivity(logSink);
    
    // Step 3: Test Firebase connection
    await verifyFirebaseConnection(logSink);
    
    // Step 4: Test basic write operations
    await verifyBasicWriteOperations(logSink);
    
    // Step 5: Test diagnostic data upload
    await verifyDiagnosticDataUpload(logSink);
    
    // Step 6: Verify uploaded data
    await verifyUploadedData(logSink);
    
    print('✅ ALL VERIFICATION TESTS COMPLETED SUCCESSFULLY');
    logSink.writeln('=== VERIFICATION COMPLETED ===');
    
  } catch (e) {
    print('❌ VERIFICATION FAILED: $e');
    logSink.writeln('=== VERIFICATION FAILED: $e ===');
  } finally {
    await logSink.close();
    print('📝 Detailed log saved to: firebase_upload_log.txt');
    print('');
    print('To view the complete log:');
    print('cat firebase_upload_log.txt');
  }
}

Future<void> verifyFirebaseInitialization(IOSink logSink) async {
  print('\n--- STEP 1: Firebase Initialization Verification ---');
  logSink.writeln('\n=== STEP 1: FIREBASE INITIALIZATION ===');
  
  try {
    logSink.writeln('Attempting to initialize Firebase...');
    print('🔄 Initializing Firebase...');
    
    // Try to initialize using the service method
    await FirebaseDatabaseService.initializeFirebase();
    
    logSink.writeln('✅ Firebase initialized successfully via service');
    print('✅ Firebase initialized successfully via service');
    
    // Verify Firebase app instance
    final app = Firebase.app();
    logSink.writeln('Firebase App name: ${app.name}');
    logSink.writeln('Firebase App options: ${app.options.toString()}');
    print('📊 Firebase App: ${app.name}');
    
    // Check database URL
    final databaseURL = FirebaseDatabase.instance.databaseURL;
    logSink.writeln('Database URL: $databaseURL');
    print('🌐 Database URL: $databaseURL');
    
  } catch (e) {
    logSink.writeln('❌ Firebase initialization failed: $e');
    logSink.writeln('Stack trace: ${StackTrace.current}');
    print('❌ Firebase initialization failed: $e');
    rethrow;
  }
}

Future<void> verifyNetworkConnectivity(IOSink logSink) async {
  print('\n--- STEP 2: Network Connectivity Verification ---');
  logSink.writeln('\n=== STEP 2: NETWORK CONNECTIVITY ===');
  
  try {
    logSink.writeln('Checking network connectivity...');
    print('🌐 Checking network connectivity...');
    
    final connectivityResult = await Connectivity().checkConnectivity();
    logSink.writeln('Connectivity result: $connectivityResult');
    print('📶 Connectivity: $connectivityResult');
    
    // Use service method for consistency
    final hasNetwork = await FirebaseDatabaseService.checkNetworkConnectivity();
    logSink.writeln('Service connectivity check: $hasNetwork');
    print('🔗 Service connectivity: $hasNetwork');
    
    if (!hasNetwork) {
      logSink.writeln('❌ No network connectivity available');
      print('❌ No network connectivity - uploads will fail');
      throw Exception('No network connectivity available');
    }
    
  } catch (e) {
    logSink.writeln('❌ Network connectivity check failed: $e');
    print('❌ Network connectivity failed: $e');
    rethrow;
  }
}

Future<void> verifyFirebaseConnection(IOSink logSink) async {
  print('\n--- STEP 3: Firebase Connection Verification ---');
  logSink.writeln('\n=== STEP 3: FIREBASE CONNECTION ===');
  
  try {
    logSink.writeln('Testing Firebase availability...');
    print('🔥 Testing Firebase connection...');
    
    final isAvailable = await FirebaseDatabaseService.isFirebaseAvailable();
    logSink.writeln('Firebase availability: $isAvailable');
    print('📡 Firebase available: $isAvailable');
    
    if (!isAvailable) {
      logSink.writeln('❌ Firebase is not available');
      print('❌ Firebase not available - check configuration');
      throw Exception('Firebase is not available');
    }
    
    // Test direct database connection
    logSink.writeln('Testing direct database connection...');
    final database = FirebaseDatabase.instance.ref();
    final testRef = database.child('.info/connected');
    final snapshot = await testRef.get().timeout(Duration(seconds: 10));
    
    logSink.writeln('Direct connection test: ${snapshot.exists}');
    logSink.writeln('Connected status: ${snapshot.value}');
    print('🔗 Direct connection: ${snapshot.value}');
    
  } catch (e) {
    logSink.writeln('❌ Firebase connection test failed: $e');
    print('❌ Firebase connection failed: $e');
    rethrow;
  }
}

Future<void> verifyBasicWriteOperations(IOSink logSink) async {
  print('\n--- STEP 4: Basic Write Operations Verification ---');
  logSink.writeln('\n=== STEP 4: BASIC WRITE OPERATIONS ===');
  
  try {
    final database = FirebaseDatabase.instance.ref();
    final testPath = 'verification_test/${DateTime.now().millisecondsSinceEpoch}';
    
    logSink.writeln('Test path: $testPath');
    print('📝 Testing basic write operations...');
    
    // Test 1: Simple write
    final testData = {
      'testType': 'verification',
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'testing',
    };
    
    logSink.writeln('Writing test data: $testData');
    await database.child('$testPath/basic_write').set(testData).timeout(Duration(seconds: 15));
    logSink.writeln('✅ Basic write successful');
    print('✅ Basic write successful');
    
    // Test 2: Read back
    logSink.writeln('Reading back test data...');
    final snapshot = await database.child('$testPath/basic_write').get().timeout(Duration(seconds: 15));
    
    if (snapshot.exists) {
      logSink.writeln('✅ Read successful: ${snapshot.value}');
      print('✅ Read verification successful');
    } else {
      logSink.writeln('❌ Read failed - no data found');
      print('❌ Read verification failed');
      throw Exception('Read verification failed');
    }
    
    // Test 3: Update operation
    logSink.writeln('Testing update operation...');
    await database.child('$testPath/basic_write').update({
      'status': 'updated',
      'updateTimestamp': DateTime.now().toIso8601String(),
    }).timeout(Duration(seconds: 15));
    
    logSink.writeln('✅ Update successful');
    print('✅ Update operation successful');
    
    // Cleanup
    await database.child(testPath).remove().timeout(Duration(seconds: 15));
    logSink.writeln('✅ Cleanup successful');
    print('🧹 Test data cleaned up');
    
  } catch (e) {
    logSink.writeln('❌ Basic write operations failed: $e');
    print('❌ Basic write operations failed: $e');
    rethrow;
  }
}

Future<void> verifyDiagnosticDataUpload(IOSink logSink) async {
  print('\n--- STEP 5: Diagnostic Data Upload Verification ---');
  logSink.writeln('\n=== STEP 5: DIAGNOSTIC DATA UPLOAD ===');
  
  try {
    // Create comprehensive test data
    final testDeviceId = 'verification_device_${DateTime.now().millisecondsSinceEpoch}';
    final testDeviceInfo = {
      'manufacturer': 'Verification Test Manufacturer',
      'model': 'Verification Test Model',
      'androidVersion': '13',
      'id': testDeviceId,
      'testType': 'verification_upload',
    };
    
    final testResults = [
      {
        'name': 'Verification Speaker Test',
        'icon': Icons.volume_up,
        'status': 'Passed',
        'instruction': 'Test instruction for speaker verification',
        'details': 'Speaker working correctly',
      },
      {
        'name': 'Verification Microphone Test',
        'icon': Icons.mic,
        'status': 'Passed',
        'instruction': 'Test instruction for microphone verification',
        'details': 'Microphone capturing audio properly',
      },
      {
        'name': 'Verification Vibration Test',
        'icon': Icons.vibration,
        'status': 'Failed',
        'instruction': 'Test instruction for vibration verification',
        'details': 'Vibration motor not responding',
      },
    ];
    
    logSink.writeln('Device ID: $testDeviceId');
    logSink.writeln('Device info: $testDeviceInfo');
    logSink.writeln('Test results count: ${testResults.length}');
    print('📤 Testing diagnostic data upload...');
    print('📱 Device ID: $testDeviceId');
    
    // Upload using the service method
    final success = await FirebaseDatabaseService.uploadDiagnosticResults(
      deviceId: testDeviceId,
      deviceInfo: testDeviceInfo,
      testResults: testResults,
      overallScore: 67,
      testDuration: 'Verification Test Duration: 2 minutes',
    );
    
    logSink.writeln('Upload result: $success');
    print('📊 Upload result: $success');
    
    if (!success) {
      logSink.writeln('❌ Diagnostic data upload failed');
      print('❌ Diagnostic data upload failed');
      throw Exception('Diagnostic data upload failed');
    }
    
    // Store device ID for next verification step
    logSink.writeln('STORED_DEVICE_ID:$testDeviceId');
    print('✅ Diagnostic data uploaded successfully');
    
  } catch (e) {
    logSink.writeln('❌ Diagnostic data upload verification failed: $e');
    print('❌ Diagnostic data upload failed: $e');
    rethrow;
  }
}

Future<void> verifyUploadedData(IOSink logSink) async {
  print('\n--- STEP 6: Uploaded Data Verification ---');
  logSink.writeln('\n=== STEP 6: UPLOADED DATA VERIFICATION ===');
  
  try {
    // Read the log file to get the device ID
    final logContent = await File('firebase_upload_log.txt').readAsString();
    final deviceIdMatch = RegExp(r'STORED_DEVICE_ID:(.+)').firstMatch(logContent);
    
    if (deviceIdMatch == null) {
      throw Exception('Could not find stored device ID for verification');
    }
    
    final testDeviceId = deviceIdMatch.group(1)!;
    logSink.writeln('Verifying data for device: $testDeviceId');
    print('🔍 Verifying uploaded data for: $testDeviceId');
    
    // Retrieve uploaded data
    final uploadedData = await FirebaseDatabaseService.getDeviceDiagnostics(testDeviceId);
    
    if (uploadedData == null) {
      logSink.writeln('❌ No uploaded data found for device');
      print('❌ No uploaded data found');
      throw Exception('No uploaded data found');
    }
    
    logSink.writeln('✅ Uploaded data retrieved successfully');
    logSink.writeln('Data keys: ${uploadedData.keys.toList()}');
    print('✅ Uploaded data retrieved successfully');
    print('📋 Data structure: ${uploadedData.keys.toList()}');
    
    // Verify specific fields
    final expectedFields = ['deviceId', 'lastTest', 'deviceInfo', 'latestScore', 'testHistory'];
    for (final field in expectedFields) {
      if (uploadedData.containsKey(field)) {
        logSink.writeln('✅ Field present: $field');
        print('✅ Field verified: $field');
      } else {
        logSink.writeln('❌ Missing field: $field');
        print('❌ Missing field: $field');
      }
    }
    
    // Verify test history
    if (uploadedData.containsKey('testHistory')) {
      final testHistory = uploadedData['testHistory'];
      logSink.writeln('Test history entries: ${testHistory.keys.toList()}');
      print('📜 Test history entries: ${testHistory.keys.length}');
      
      // Check first test entry
      if (testHistory is Map && testHistory.isNotEmpty) {
        final firstTestKey = testHistory.keys.first;
        final firstTest = testHistory[firstTestKey];
        
        logSink.writeln('First test data: $firstTest');
        print('🔬 First test verified: ${firstTestKey}');
      }
    }
    
    print('✅ All uploaded data verified successfully');
    
  } catch (e) {
    logSink.writeln('❌ Uploaded data verification failed: $e');
    print('❌ Data verification failed: $e');
    rethrow;
  }
}
