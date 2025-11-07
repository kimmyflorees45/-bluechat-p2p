import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BlueChatApp());
}

class BlueChatApp extends StatelessWidget {
  const BlueChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueChat P2P',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  List<BluetoothDiscoveryResult> _discoveryResults = [];
  List<BluetoothDevice> _bondedDevices = [];
  bool _isDiscovering = false;
  bool _isDiscoverable = false;
  String _deviceName = "BlueChat Device";

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  void _initializeBluetooth() async {
    try {
      // Verificar estado inicial
      BluetoothState state = await FlutterBluetoothSerial.instance.state;
      setState(() {
        _bluetoothState = state;
      });

      // Obtener nombre del dispositivo
      String? name = await FlutterBluetoothSerial.instance.name;
      if (name != null && name.isNotEmpty) {
        setState(() {
          _deviceName = name;
        });
      }

      // Escuchar cambios de estado
      FlutterBluetoothSerial.instance.onStateChanged().listen((BluetoothState state) {
        setState(() {
          _bluetoothState = state;
        });
        if (state == BluetoothState.STATE_ON) {
          _getBondedDevices();
          _makeDiscoverable();
        }
      });

      if (state == BluetoothState.STATE_ON) {
        _getBondedDevices();
        _makeDiscoverable();
      }
    } catch (e) {
      print('Error initializing Bluetooth: $e');
    }
  }

  void _makeDiscoverable() async {
    try {
      int? result = await FlutterBluetoothSerial.instance.requestDiscoverable(300);
      setState(() {
        _isDiscoverable = result != null && result > 0;
      });
    } catch (e) {
      print('Error making discoverable: $e');
    }
  }

  void _getBondedDevices() async {
    try {
      List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _bondedDevices = bondedDevices;
      });
    } catch (ex) {
      print('Error getting bonded devices: $ex');
    }
  }

  void _startDiscovery() {
    setState(() {
      _isDiscovering = true;
      _discoveryResults.clear();
    });

    FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
      setState(() {
        final existingIndex = _discoveryResults.indexWhere((element) => element.device.address == result.device.address);
        if (existingIndex >= 0) {
          _discoveryResults[existingIndex] = result;
        } else {
          _discoveryResults.add(result);
        }
      });
    }).onDone(() {
      setState(() {
        _isDiscovering = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BlueChat P2P'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isDiscovering ? Icons.stop : Icons.refresh),
            onPressed: _bluetoothState.isEnabled && !_isDiscovering ? _startDiscovery : null,
          ),
          IconButton(
            icon: Icon(_isDiscoverable ? Icons.visibility : Icons.visibility_off),
            onPressed: _bluetoothState.isEnabled ? _makeDiscoverable : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: _bluetoothState.isEnabled ? Colors.green.shade50 : Colors.red.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      color: _bluetoothState.isEnabled ? Colors.green : Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BlueChat P2P',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _bluetoothState.isEnabled 
                                ? 'Dispositivo: $_deviceName'
                                : 'Habilita Bluetooth para usar la app',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isDiscovering)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (_bluetoothState.isEnabled)
                  Row(
                    children: [
                      Icon(
                        _isDiscoverable ? Icons.visibility : Icons.visibility_off,
                        color: _isDiscoverable ? Colors.green : Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isDiscoverable 
                            ? 'Visible para otros dispositivos'
                            : 'Toca para hacerte visible',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isDiscoverable ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (!_bluetoothState.isEnabled)
            Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  FlutterBluetoothSerial.instance.requestEnable();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Habilitar Bluetooth'),
              ),
            ),
          if (_bondedDevices.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dispositivos Emparejados:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...(_bondedDevices.map((device) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth_connected, color: Colors.green),
                      title: Text(device.name?.isNotEmpty == true ? device.name! : 'Dispositivo ${device.address.substring(device.address.length - 5)}'),
                      subtitle: Text(device.address),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(device: device),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Conectar'),
                      ),
                    ),
                  )).toList()),
                ],
              ),
            ),
          Expanded(
            child: _discoveryResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bluetooth_searching,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isDiscovering 
                              ? 'Buscando dispositivos...'
                              : 'No hay dispositivos disponibles',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Toca el botón de actualizar para buscar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Dispositivos Encontrados:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _discoveryResults.length,
                          itemBuilder: (context, index) {
                            final result = _discoveryResults[index];
                            final device = result.device;
                            String displayName = device.name?.isNotEmpty == true 
                                ? device.name! 
                                : 'Dispositivo ${device.address.substring(device.address.length - 5)}';
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.phone_android,
                                  color: result.rssi != null && result.rssi! > -60 ? Colors.green : Colors.orange,
                                ),
                                title: Text(displayName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(device.address),
                                    if (result.rssi != null)
                                      Text('Señal: ${result.rssi} dBm', 
                                        style: TextStyle(
                                          color: result.rssi! > -60 ? Colors.green : Colors.orange,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(device: device),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Conectar'),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final BluetoothDevice device;

  const ChatScreen({super.key, required this.device});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  BluetoothConnection? connection;
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isConnected = false;
  bool _isConnecting = true;
  bool _showStickers = false;
  Map<String, dynamic> _stickersData = {};
  double _fontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _connectToDevice();
    _loadStickers();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('fontSize') ?? 14.0;
    });
  }

  void _saveFontSize() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', _fontSize);
  }

  void _loadStickers() async {
    try {
      final String response = await rootBundle.loadString('assets/stickers/stickers_data.json');
      final data = await json.decode(response);
      setState(() {
        _stickersData = data;
      });
    } catch (e) {
      print('Error loading stickers: $e');
    }
  }

  void _connectToDevice() async {
    try {
      connection = await BluetoothConnection.toAddress(widget.device.address);
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });

      connection!.input!.listen((Uint8List data) {
        String receivedData = String.fromCharCodes(data);
        try {
          final parsed = json.decode(receivedData);
          if (parsed['type'] == 'sticker') {
            setState(() {
              _messages.add(ChatMessage(
                parsed['content'], 
                false, 
                DateTime.now(),
                isSticker: true,
              ));
            });
          } else {
            setState(() {
              _messages.add(ChatMessage(receivedData.trim(), false, DateTime.now()));
            });
          }
        } catch (e) {
          setState(() {
            _messages.add(ChatMessage(receivedData.trim(), false, DateTime.now()));
          });
        }
      }).onDone(() {
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
        }
      });
    } catch (exception) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isConnecting = false;
        });
      }
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty && _isConnected) {
      String message = _messageController.text.trim();
      try {
        connection!.output.add(Uint8List.fromList(message.codeUnits));
        
        setState(() {
          _messages.add(ChatMessage(message, true, DateTime.now()));
        });
        _messageController.clear();
      } catch (e) {
        print('Error sending message: $e');
      }
    }
  }

  void _sendSticker(String emoji) {
    if (_isConnected) {
      try {
        final stickerData = json.encode({
          'type': 'sticker',
          'content': emoji,
        });
        connection!.output.add(Uint8List.fromList(stickerData.codeUnits));
        
        setState(() {
          _messages.add(ChatMessage(emoji, true, DateTime.now(), isSticker: true));
          _showStickers = false;
        });
      } catch (e) {
        print('Error sending sticker: $e');
      }
    }
  }

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String deviceDisplayName = widget.device.name?.isNotEmpty == true 
        ? widget.device.name! 
        : 'Dispositivo ${widget.device.address.substring(widget.device.address.length - 5)}';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deviceDisplayName),
            Text(
              _isConnecting 
                  ? 'Conectando...' 
                  : (_isConnected ? 'Conectado' : 'Desconectado'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showStickers ? Icons.keyboard : Icons.emoji_emotions),
            onPressed: () {
              setState(() {
                _showStickers = !_showStickers;
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'font_size') {
                _showFontSizeDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'font_size',
                child: Row(
                  children: [
                    Icon(Icons.text_fields),
                    SizedBox(width: 8),
                    Text('Tamaño de letra'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isConnecting)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Conectando...'),
                ],
              ),
            ),
          if (!_isConnected && !_isConnecting)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Error de conexión')),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isConnecting = true;
                      });
                      _connectToDevice();
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: message.isMe 
                        ? MainAxisAlignment.end 
                        : MainAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: message.isMe ? Colors.blue : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            message.isSticker 
                                ? Text(
                                    message.text,
                                    style: const TextStyle(fontSize: 32),
                                  )
                                : Text(
                                    message.text,
                                    style: TextStyle(
                                      color: message.isMe ? Colors.white : Colors.black,
                                      fontSize: _fontSize,
                                    ),
                                  ),
                            const SizedBox(height: 4),
                            Text(
                              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: message.isMe 
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_showStickers && _stickersData.isNotEmpty)
            Container(
              height: 200,
              color: Colors.grey.shade100,
              child: DefaultTabController(
                length: (_stickersData['packs'] as List).length,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                      tabs: (_stickersData['packs'] as List).map<Widget>((pack) {
                        return Tab(text: pack['name']);
                      }).toList(),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: (_stickersData['packs'] as List).map<Widget>((pack) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              childAspectRatio: 1,
                            ),
                            itemCount: (pack['stickers'] as List).length,
                            itemBuilder: (context, index) {
                              final sticker = (pack['stickers'] as List)[index];
                              return GestureDetector(
                                onTap: () => _sendSticker(sticker['emoji']),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Center(
                                    child: Text(
                                      sticker['emoji'],
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: _isConnected,
                    style: TextStyle(fontSize: _fontSize),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _isConnected ? _sendMessage : null,
                  backgroundColor: _isConnected ? Colors.blue : Colors.grey,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tamaño de letra'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tamaño actual: ${_fontSize.toInt()}', style: TextStyle(fontSize: _fontSize)),
                  const SizedBox(height: 16),
                  Slider(
                    value: _fontSize,
                    min: 10.0,
                    max: 24.0,
                    divisions: 14,
                    label: _fontSize.toInt().toString(),
                    onChanged: (double value) {
                      setDialogState(() {
                        _fontSize = value;
                      });
                      setState(() {
                        _fontSize = value;
                      });
                      _saveFontSize();
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final bool isSticker;

  ChatMessage(this.text, this.isMe, this.timestamp, {this.isSticker = false});
}
