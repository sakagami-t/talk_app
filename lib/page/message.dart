import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  MessageScreenState createState() => MessageScreenState();
}

class MessageScreenState extends State<MessageScreen> {
  final List<String> _messages = [];
  final TextEditingController _controller = TextEditingController();
  WebSocketChannel? _channel;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    super.dispose();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(
            'wss://buc0rvxhnh.execute-api.ap-northeast-1.amazonaws.com/prod'),
      );

      _channel!.stream.listen(
        (message) {
          final data = json.decode(message);
          setState(() {
            _messages.add(data['content']);
          });
        },
        onDone: _handleDisconnect,
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _handleDisconnect();
        },
      );

      setState(() {
        _isConnected = true;
        _reconnectAttempts = 0;
      });
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    setState(() {
      _isConnected = false;
    });

    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      Future.delayed(
        Duration(seconds: 2 * _reconnectAttempts),
        _connectWebSocket,
      );
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await http.get(Uri.parse(
          'https://q3a6g0zjk9.execute-api.ap-northeast-1.amazonaws.com/conversationHistory?user_id=a&conversation_id=bb141ab3-72bb-3369-ed52-aaebd12dbfbf'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> messages = data['messages'];
        setState(() {
          _messages.clear();
          for (var message in messages) {
            _messages.add(message['content']);
          }
        });
      } else {
        throw Exception('Failed to load messages');
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      // エラーをユーザーに表示するなどの処理を追加
    }
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty && _isConnected) {
      final message = {
        'action': 'sendmessage',
        'message': _controller.text,
        'conversation_id': 'bb141ab3-72bb-3369-ed52-aaebd12dbfbf',
      };

      try {
        // 自分のメッセージをすぐに追加
        setState(() {
          _messages.add(_controller.text);
        });
        _channel!.sink.add(json.encode(message));

        // メッセージ送信後にテキストフィールドをクリア
        setState(() {
          _controller.clear();
        });
      } catch (e) {
        debugPrint('Error sending message: $e');
        // エラーをユーザーに表示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } else if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to chat server')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Screen'),
        actions: [
          // 接続状態を表示するインジケーター
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              _isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter message',
                    ),
                    // Enterキーでメッセージを送信
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: _isConnected ? null : Colors.grey,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
