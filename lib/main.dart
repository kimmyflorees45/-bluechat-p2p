import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
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
  String _deviceName = "BlueChat Device";
  Color _primaryColor = Colors.blue;
  bool _isServerRunning = false;
  BluetoothConnection? _serverConnection;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
    _loadSettings();
    _startServer();
  }

  void _loadSettings() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _primaryColor = Color(prefs.getInt('primaryColor') ?? Colors.blue.value);
      });
    } catch (e) {
      // Ignorar errores de configuración
    }
  }

  void _initializeBluetooth() async {
    try {
      BluetoothState state = await FlutterBluetoothSerial.instance.state;
      if (mounted) {
        setState(() {
          _bluetoothState = state;
        });
      }

      String? name = await FlutterBluetoothSerial.instance.name;
      if (name != null && name.isNotEmpty && mounted) {
        setState(() {
          _deviceName = name;
        });
      }

      FlutterBluetoothSerial.instance.onStateChanged().listen((BluetoothState state) {
        if (mounted) {
          setState(() {
            _bluetoothState = state;
          });
          if (state == BluetoothState.STATE_ON) {
            _getBondedDevices();
            _startServer();
          }
        }
      });

      if (state == BluetoothState.STATE_ON) {
        _getBondedDevices();
        _startServer();
      }
    } catch (e) {
      print('Error initializing Bluetooth: $e');
    }
  }

  void _startServer() async {
    if (_bluetoothState != BluetoothState.STATE_ON) return;
    
    try {
      // Hacer el dispositivo visible
      await FlutterBluetoothSerial.instance.requestDiscoverable(300);
      
      setState(() {
        _isServerRunning = true;
      });
      
      print('BlueChat server started and discoverable');
    } catch (e) {
      print('Error starting server: $e');
    }
  }

  void _getBondedDevices() async {
    try {
      List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      
      // Filtrar solo dispositivos móviles (celulares)
      List<BluetoothDevice> mobileDevices = bondedDevices.where((device) {
        if (device.name == null) return false;
        
        String deviceName = device.name!.toLowerCase();
        
        // Excluir dispositivos que NO son celulares
        List<String> excludeKeywords = [
          'headphone', 'headset', 'earphone', 'earbud', 'airpod', 'buds',
          'speaker', 'bocina', 'altavoz', 'soundbar',
          'keyboard', 'teclado', 'mouse', 'ratón',
          'watch', 'reloj', 'band', 'fit',
          'tv', 'smart tv', 'chromecast', 'roku',
          'car', 'auto', 'vehicle', 'coche',
          'printer', 'impresora',
          'laptop', 'pc', 'computer', 'ordenador'
        ];
        
        // Si contiene palabras excluidas, no incluir
        for (String keyword in excludeKeywords) {
          if (deviceName.contains(keyword)) {
            return false;
          }
        }
        
        // Incluir dispositivos que son claramente celulares
        List<String> mobileKeywords = [
          'phone', 'móvil', 'movil', 'celular', 'smartphone',
          'android', 'samsung', 'galaxy', 'note', 'edge',
          'xiaomi', 'redmi', 'poco', 'mi ',
          'huawei', 'honor', 'mate', 'nova', 'p30', 'p40', 'p50',
          'iphone', 'apple',
          'oneplus', 'realme', 'oppo', 'vivo',
          'lg', 'sony', 'xperia',
          'motorola', 'moto',
          'nokia', 'asus', 'rog phone',
          'blackshark', 'black shark', 'redmagic', 'red magic'
        ];
        
        // Si contiene palabras de móviles, incluir
        for (String keyword in mobileKeywords) {
          if (deviceName.contains(keyword)) {
            return true;
          }
        }
        
        // Si el nombre es genérico pero no está en la lista de exclusión, incluir
        // (podría ser un celular con nombre personalizado)
        return deviceName.length > 3 && !deviceName.contains('unknown');
      }).toList();
      
      if (mounted) {
        setState(() {
          _bondedDevices = mobileDevices;
        });
      }
    } catch (ex) {
      print('Error getting bonded devices: $ex');
    }
  }

  void _startDiscovery() {
    if (!_bluetoothState.isEnabled) return;
    
    setState(() {
      _isDiscovering = true;
      _discoveryResults.clear();
    });

    try {
      FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
        if (mounted) {
          // Filtrar solo dispositivos móviles
          bool isMobileDevice = _isMobileDevice(result.device);
          
          if (isMobileDevice) {
            setState(() {
              final existingIndex = _discoveryResults.indexWhere((element) => element.device.address == result.device.address);
              if (existingIndex >= 0) {
                _discoveryResults[existingIndex] = result;
              } else {
                _discoveryResults.add(result);
              }
            });
          }
        }
      }).onDone(() {
        if (mounted) {
          setState(() {
            _isDiscovering = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
      }
    }
  }

  bool _isMobileDevice(BluetoothDevice device) {
    if (device.name == null) return false;
    
    String deviceName = device.name!.toLowerCase();
    
    // Excluir dispositivos que NO son celulares
    List<String> excludeKeywords = [
      'headphone', 'headset', 'earphone', 'earbud', 'airpod', 'buds',
      'speaker', 'bocina', 'altavoz', 'soundbar',
      'keyboard', 'teclado', 'mouse', 'ratón',
      'watch', 'reloj', 'band', 'fit',
      'tv', 'smart tv', 'chromecast', 'roku',
      'car', 'auto', 'vehicle', 'coche',
      'printer', 'impresora',
      'laptop', 'pc', 'computer', 'ordenador'
    ];
    
    // Si contiene palabras excluidas, no incluir
    for (String keyword in excludeKeywords) {
      if (deviceName.contains(keyword)) {
        return false;
      }
    }
    
    // Incluir dispositivos que son claramente celulares
    List<String> mobileKeywords = [
      'phone', 'móvil', 'movil', 'celular', 'smartphone',
      'android', 'samsung', 'galaxy', 'note', 'edge',
      'xiaomi', 'redmi', 'poco', 'mi ',
      'huawei', 'honor', 'mate', 'nova', 'p30', 'p40', 'p50',
      'iphone', 'apple',
      'oneplus', 'realme', 'oppo', 'vivo',
      'lg', 'sony', 'xperia',
      'motorola', 'moto',
      'nokia', 'asus', 'rog phone',
      'blackshark', 'black shark', 'redmagic', 'red magic'
    ];
    
    // Si contiene palabras de móviles, incluir
    for (String keyword in mobileKeywords) {
      if (deviceName.contains(keyword)) {
        return true;
      }
    }
    
    // Si el nombre es genérico pero no está en la lista de exclusión, incluir
    // (podría ser un celular con nombre personalizado)
    return deviceName.length > 3 && !deviceName.contains('unknown');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          Container(
            padding: const EdgeInsets.all(16),
            color: _bluetoothState.isEnabled ? Colors.green.shade50 : Colors.red.shade50,
            child: Row(
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
                      if (_isServerRunning)
                        const Text(
                          '📡 Servidor BlueChat activo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
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
          ),
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
                    'Celulares Emparejados:',
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
                              builder: (context) => ChatScreen(device: device, primaryColor: _primaryColor),
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
                              ? 'Buscando celulares...'
                              : 'No hay celulares disponibles',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_isDiscovering)
                          ElevatedButton(
                            onPressed: _bluetoothState.isEnabled ? _startDiscovery : null,
                            child: const Text('Buscar Celulares'),
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
                                  builder: (context) => ChatScreen(device: device, primaryColor: _primaryColor),
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
                    try {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('primaryColor', colors[index].value);
                    } catch (e) {
                      // Ignorar errores
                    }
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

  const ChatScreen({super.key, required this.device, required this.primaryColor});

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
  Timer? _connectionTimer;
  int _retryCount = 0;

  // Stickers expandidos - Trabajo en equipo
  final List<String> _stickers = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
    '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
    '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩',
    '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣',
    '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬',
    '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓', '🤗',
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉',
    '👆', '👇', '☝️', '✋', '🤚', '🖐️', '🖖', '👋', '🤝', '🙏',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _connectToDevice();
  }

  void _loadSettings() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _fontSize = prefs.getDouble('fontSize') ?? 14.0;
        });
      }
    } catch (e) {
      // Ignorar errores
    }
  }

  void _connectToDevice() async {
    if (!mounted) return;
    
    try {
      // Verificar estado de Bluetooth
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

      // Timeout más largo para la conexión
      _connectionTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && _isConnecting) {
          setState(() {
            _isConnected = false;
            _isConnecting = false;
          });
          _showRetryDialog();
        }
      });

      // Esperar un momento antes de conectar
      await Future.delayed(const Duration(seconds: 1));

      // Intentar conectar
      connection = await BluetoothConnection.toAddress(widget.device.address);
      
      _connectionTimer?.cancel();
      
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
          _retryCount = 0;
        });
      }

      // Enviar mensaje de handshake
      _messageController.text = "BlueChat conectado!";
      _sendMessage();
      _messageController.clear();

      // Escuchar mensajes
      connection!.input!.listen((Uint8List data) {
        if (!mounted) return;
        
        try {
          String receivedData = String.fromCharCodes(data);
          if (receivedData.trim().isNotEmpty) {
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
          }
        } catch (e) {
          print('Error processing message: $e');
        }
      }).onDone(() {
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
        }
      });
    } catch (exception) {
      _connectionTimer?.cancel();
      print('Connection error: $exception');
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isConnecting = false;
        });
        _showRetryDialog();
      }
    }
  }

  void _showRetryDialog() {
    if (_retryCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo conectar después de 3 intentos. Asegúrate de que ambos dispositivos tengan BlueChat activo.'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error de conexión'),
        content: Text('No se pudo conectar con ${widget.device.name}. Asegúrate de que ambos dispositivos tengan BlueChat abierto.\n\nIntento ${_retryCount + 1}/3'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isConnecting = true;
                _retryCount++;
              });
              _connectToDevice();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty && _isConnected && connection != null) {
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
    if (_isConnected && connection != null) {
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
    _connectionTimer?.cancel();
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
                  : (_isConnected ? 'Conectado ✅' : 'Desconectado ❌'),
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
                  const Expanded(child: Text('❌ Error de conexión')),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isConnecting = true;
                        _retryCount = 0;
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
                itemCount: _stickers.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _sendSticker(_stickers[index]),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          _stickers[index],
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
