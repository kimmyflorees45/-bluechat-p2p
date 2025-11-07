import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import '../models/message.dart';
import 'database_service.dart';
import 'notification_service.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final Map<String, BluetoothConnection> _connections = {};
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  // Streams
  final _messageStreamController = StreamController<Message>.broadcast();
  final _connectionStreamController = StreamController<Map<String, bool>>.broadcast();

  Stream<Message> get messageStream => _messageStreamController.stream;
  Stream<Map<String, bool>> get connectionStream => _connectionStreamController.stream;

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      BluetoothConnection connection = await BluetoothConnection.toAddress(device.address);
      _connections[device.address] = connection;

      // Listen for incoming data
      connection.input!.listen((Uint8List data) {
        String message = utf8.decode(data);
        _handleIncomingMessage(message, device.address, device.name ?? 'Unknown');
      }).onDone(() {
        _connections.remove(device.address);
        _updateConnectionStatus();
      });

      _updateConnectionStatus();
      
      // Show connection notification
      await _notificationService.showConnectionNotification(
        deviceName: device.name ?? 'Unknown Device',
        connected: true,
      );

      return true;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      return false;
    }
  }

  void _handleIncomingMessage(String messageData, String deviceAddress, String deviceName) {
    try {
      Map<String, dynamic> data = json.decode(messageData);
      
      Message message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: data['text'] ?? '',
        isFromMe: false,
        timestamp: DateTime.now(),
        deviceAddress: deviceAddress,
        messageType: MessageType.values.firstWhere(
          (e) => e.toString() == 'MessageType.${data['type'] ?? 'text'}',
          orElse: () => MessageType.text,
        ),
        filePath: data['filePath'],
      );

      // Save to database
      _databaseService.saveMessage(message);

      // Add to stream
      _messageStreamController.add(message);

      // Show notification
      _notificationService.showMessageNotification(
        deviceName: deviceName,
        message: message.text,
        deviceAddress: deviceAddress,
      );

    } catch (e) {
      debugPrint('Error handling incoming message: $e');
    }
  }

  Future<bool> sendMessage(String text, {String? deviceAddress}) async {
    try {
      if (deviceAddress != null && _connections.containsKey(deviceAddress)) {
        BluetoothConnection connection = _connections[deviceAddress]!;
        
        Message message = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          isFromMe: true,
          timestamp: DateTime.now(),
          deviceAddress: deviceAddress,
          messageType: MessageType.text,
        );

        Map<String, dynamic> data = {
          'text': text,
          'type': 'text',
          'timestamp': message.timestamp.toIso8601String(),
        };

        String jsonData = json.encode(data);
        connection.output.add(utf8.encode(jsonData));
        await connection.output.allSent;

        // Save to database
        await _databaseService.saveMessage(message);

        // Add to stream
        _messageStreamController.add(message);

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  Future<bool> sendFile(String filePath, {String? deviceAddress}) async {
    try {
      if (deviceAddress != null && _connections.containsKey(deviceAddress)) {
        BluetoothConnection connection = _connections[deviceAddress]!;
        
        // Read file and encode to base64
        File file = File(filePath);
        List<int> fileBytes = await file.readAsBytes();
        String base64File = base64Encode(fileBytes);
        String fileName = path.basename(filePath);

        Message message = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: fileName,
          isFromMe: true,
          timestamp: DateTime.now(),
          deviceAddress: deviceAddress,
          messageType: _getMessageTypeFromFile(filePath),
          filePath: filePath,
        );

        Map<String, dynamic> data = {
          'text': fileName,
          'type': message.messageType.toString().split('.').last,
          'timestamp': message.timestamp.toIso8601String(),
          'fileData': base64File,
          'fileName': fileName,
        };

        String jsonData = json.encode(data);
        connection.output.add(utf8.encode(jsonData));
        await connection.output.allSent;

        // Save to database
        await _databaseService.saveMessage(message);

        // Add to stream
        _messageStreamController.add(message);

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending file: $e');
      return false;
    }
  }

  MessageType _getMessageTypeFromFile(String filePath) {
    String extension = path.extension(filePath).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp'].contains(extension)) {
      return MessageType.image;
    }
    return MessageType.file;
  }

  void _updateConnectionStatus() {
    Map<String, bool> status = {};
    for (String address in _connections.keys) {
      status[address] = _connections[address]!.isConnected;
    }
    _connectionStreamController.add(status);
  }

  Future<List<BluetoothDevice>> getDiscoveredDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      return devices;
    } catch (e) {
      debugPrint('Error getting discovered devices: $e');
      return [];
    }
  }

  void disconnect(String deviceAddress) {
    if (_connections.containsKey(deviceAddress)) {
      _connections[deviceAddress]!.dispose();
      _connections.remove(deviceAddress);
      _updateConnectionStatus();
    }
  }

  void disconnectAll() {
    for (BluetoothConnection connection in _connections.values) {
      connection.dispose();
    }
    _connections.clear();
    _updateConnectionStatus();
  }

  void dispose() {
    disconnectAll();
    _messageStreamController.close();
    _connectionStreamController.close();
  }
}
