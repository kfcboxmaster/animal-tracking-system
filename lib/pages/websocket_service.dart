import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/io.dart';

class WebSocketService {
  late IOWebSocketChannel _channel;

  void connect(String serverUrl) {
    _channel = IOWebSocketChannel.connect(Uri.parse(serverUrl));
  }

  void sendFrame(String targetAnimal, Uint8List imageBytes) {
    String base64Image = base64Encode(imageBytes);
    String message = "$targetAnimal,$base64Image";
    _channel.sink.add(message);
  }

  Stream<String> get processedStream => _channel.stream.map((event) => event);

  void close() {
    _channel.sink.close();
  }
}
