import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/conversation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'bluechat.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_name TEXT NOT NULL,
        device_address TEXT NOT NULL UNIQUE,
        last_message TEXT,
        last_message_time INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        is_from_me INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        message_type TEXT DEFAULT 'text',
        file_path TEXT,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id)
      )
    ''');
  }

  Future<int> insertConversation(Conversation conversation) async {
    final db = await database;
    return await db.insert(
      'conversations',
      conversation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertMessage(Message message, String deviceAddress) async {
    final db = await database;
    
    // Get or create conversation
    int conversationId = await _getOrCreateConversationId(deviceAddress, '');
    
    Map<String, dynamic> messageMap = message.toMap();
    messageMap['conversation_id'] = conversationId;
    
    int messageId = await db.insert('messages', messageMap);
    
    // Update conversation's last message
    await db.update(
      'conversations',
      {
        'last_message': message.text,
        'last_message_time': message.timestamp.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    
    return messageId;
  }

  Future<int> _getOrCreateConversationId(String deviceAddress, String deviceName) async {
    final db = await database;
    
    List<Map<String, dynamic>> result = await db.query(
      'conversations',
      where: 'device_address = ?',
      whereArgs: [deviceAddress],
    );
    
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    } else {
      return await db.insert('conversations', {
        'device_name': deviceName.isEmpty ? 'Unknown Device' : deviceName,
        'device_address': deviceAddress,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<List<Message>> getMessagesForDevice(String deviceAddress) async {
    final db = await database;
    
    List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT m.* FROM messages m
      INNER JOIN conversations c ON m.conversation_id = c.id
      WHERE c.device_address = ?
      ORDER BY m.timestamp ASC
    ''', [deviceAddress]);
    
    return result.map((map) => Message.fromMap(map)).toList();
  }

  Future<List<Conversation>> getAllConversations() async {
    final db = await database;
    
    List<Map<String, dynamic>> result = await db.query(
      'conversations',
      orderBy: 'last_message_time DESC',
    );
    
    return result.map((map) => Conversation.fromMap(map)).toList();
  }

  Future<void> deleteConversation(int conversationId) async {
    final db = await database;
    await db.delete('messages', where: 'conversation_id = ?', whereArgs: [conversationId]);
    await db.delete('conversations', where: 'id = ?', whereArgs: [conversationId]);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('conversations');
  }
}
