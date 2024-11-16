import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  MessageScreenState createState() => MessageScreenState();
}

class Message {
  final String text;
  final DateTime timestamp;

  Message(this.text) : timestamp = DateTime.now();
}

class MessageScreenState extends State<MessageScreen> {
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  WebSocketChannel? _channel;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  final ScrollController _scrollController = ScrollController();

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

  void _connectWebSocket() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(
            'wss://buc0rvxhnh.execute-api.ap-northeast-1.amazonaws.com/prod'),
      );

      await _channel!.ready;

      _channel!.stream.listen(
        (message) {
          final data = json.decode(message);
          setState(() {
            _messages.add(Message(data['content']));
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
            _messages.add(Message(message['content']));
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
          _messages.add(Message(_controller.text));
          _controller.clear();
        });
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
        _channel!.sink.add(json.encode(message));
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
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _messages[index]
                              .timestamp
                              .toLocal()
                              .toString()
                              .split(' ')[1]
                              .substring(0, 5),
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _messages[index].text,
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                    decoration: const InputDecoration(),
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
