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
  Color _primaryColor = Colors.blue;
  Color _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
    _loadSettings();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _primaryColor = Color(prefs.getInt('primaryColor') ?? Colors.blue.value);
      _backgroundColor = Color(prefs.getInt('backgroundColor') ?? Colors.white.value);
    });
  }

  void _initializeBluetooth() async {
    try {
      BluetoothState state = await FlutterBluetoothSerial.instance.state;
      setState(() {
        _bluetoothState = state;
      });

      String? name = await FlutterBluetoothSerial.instance.name;
      if (name != null && name.isNotEmpty) {
        setState(() {
          _deviceName = name;
        });
      }

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
      // Filtrar solo dispositivos que podrían tener BlueChat
      List<BluetoothDevice> filteredDevices = bondedDevices.where((device) {
        return device.name != null && 
               (device.name!.toLowerCase().contains('phone') || 
                device.name!.toLowerCase().contains('android') ||
                device.name!.toLowerCase().contains('samsung') ||
                device.name!.toLowerCase().contains('xiaomi') ||
                device.name!.toLowerCase().contains('huawei') ||
                device.name!.length > 3);
      }).toList();
      
      setState(() {
        _bondedDevices = filteredDevices;
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
      // Solo mostrar dispositivos que podrían tener BlueChat
      if (result.device.name != null && 
          (result.device.name!.toLowerCase().contains('phone') || 
           result.device.name!.toLowerCase().contains('android') ||
           result.device.name!.toLowerCase().contains('samsung') ||
           result.device.name!.toLowerCase().contains('xiaomi') ||
           result.device.name!.toLowerCase().contains('huawei') ||
           result.device.name!.length > 3)) {
        setState(() {
          final existingIndex = _discoveryResults.indexWhere((element) => element.device.address == result.device.address);
          if (existingIndex >= 0) {
            _discoveryResults[existingIndex] = result;
          } else {
            _discoveryResults.add(result);
          }
        });
      }
    }).onDone(() {
      setState(() {
        _isDiscovering = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('BlueChat P2P'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isDiscovering ? Icons.stop : Icons.refresh),
            onPressed: _bluetoothState.isEnabled && !_isDiscovering ? _startDiscovery : null,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          if (!_bluetoothState.isEnabled)
            Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  FlutterBluetoothSerial.instance.requestEnable();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
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
                    'Dispositivos con BlueChat:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...(_bondedDevices.map((device) => Card(
                    child: ListTile(
                      leading: Icon(Icons.smartphone, color: _primaryColor),
                      title: Text(device.name ?? 'Dispositivo ${device.address.substring(device.address.length - 5)}'),
                      subtitle: Text(device.address),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(device: device, primaryColor: _primaryColor, backgroundColor: _backgroundColor),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
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
                        Icon(
                          Icons.bluetooth_searching,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isDiscovering 
                              ? 'Buscando dispositivos con BlueChat...'
                              : 'No hay dispositivos BlueChat disponibles',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _discoveryResults.length,
                    itemBuilder: (context, index) {
                      final result = _discoveryResults[index];
                      final device = result.device;
                      String displayName = device.name ?? 'Dispositivo ${device.address.substring(device.address.length - 5)}';
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.smartphone, color: _primaryColor),
                          title: Text(displayName),
                          subtitle: Text(device.address),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(device: device, primaryColor: _primaryColor, backgroundColor: _backgroundColor),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
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
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: _primaryColor,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.chat, color: Colors.white, size: 48),
                SizedBox(height: 8),
                Text(
                  'BlueChat P2P',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Chat sin internet',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Iniciar Sesión'),
            onTap: () {
              Navigator.pop(context);
              _showLoginDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Personalizar App'),
            onTap: () {
              Navigator.pop(context);
              _showCustomizationDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper),
            title: const Text('Fondo del Chat'),
            onTap: () {
              Navigator.pop(context);
              _showBackgroundDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Colores de la App'),
            onTap: () {
              Navigator.pop(context);
              _showColorDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Iniciar Sesión'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Usuario',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Iniciar Sesión'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomizationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Personalizar Aplicación'),
          content: const Text('Próximamente: Temas, avatares y más opciones de personalización.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _showBackgroundDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Fondo del Chat'),
          content: const Text('Próximamente: Fondos personalizados para el chat.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _showColorDialog() {
    List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.orange,
      Colors.teal,
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Colores de la App'),
          content: Container(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
              ),
              itemCount: colors.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () async {
                    setState(() {
                      _primaryColor = colors[index];
                    });
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('primaryColor', colors[index].value);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors[index],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _primaryColor == colors[index] ? Colors.black : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  final BluetoothDevice device;
  final Color primaryColor;
  final Color backgroundColor;

  const ChatScreen({super.key, required this.device, required this.primaryColor, required this.backgroundColor});

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
  double _fontSize = 14.0;

  // Stickers reales de Google
  final List<String> _googleStickers = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
    '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
    '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩',
    '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣',
    '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬',
    '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓', '🤗',
    '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😯',
    '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐',
    '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈',
    '👿', '👹', '👺', '🤡', '💩', '👻', '💀', '☠️', '👽', '👾',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _connectToDevice();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('fontSize') ?? 14.0;
    });
  }

  void _connectToDevice() async {
    try {
      BluetoothState state = await FlutterBluetoothSerial.instance.state;
      if (state != BluetoothState.STATE_ON) {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _isConnecting = false;
          });
        }
        return;
      }

      connection = await BluetoothConnection.toAddress(widget.device.address);
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
      }

      connection!.input!.listen((Uint8List data) {
        if (!mounted) return;
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
      backgroundColor: widget.backgroundColor,
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
        backgroundColor: widget.primaryColor,
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
        ],
      ),
      body: Column(
        children: [
          if (_isConnecting)
            Container(
              padding: const EdgeInsets.all(16),
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
                          color: message.isMe ? widget.primaryColor : Colors.grey.shade300,
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
          if (_showStickers)
            Container(
              height: 200,
              color: Colors.grey.shade100,
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _googleStickers.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _sendSticker(_googleStickers[index]),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          _googleStickers[index],
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
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
                  backgroundColor: _isConnected ? widget.primaryColor : Colors.grey,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
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
