import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(MaterialApp(home: NFCPage()));
}

class NFCPage extends StatefulWidget {
  @override
  _NFCPageState createState() => _NFCPageState();
}

class _NFCPageState extends State<NFCPage> {
  static const platform = MethodChannel('kr.co.daram.nfc_project');
  String _status = "Idle";
  double _progress = 0.0;

  Uint8List? _imageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("NFC to E-Ink Display")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("Status: $_status", style: TextStyle(fontSize: 16)),
            if (_progress > 0)
              LinearProgressIndicator(value: _progress, minHeight: 8),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _selectImage,
              child: Text("Select Image"),
            ),
            ElevatedButton(
              onPressed: _enterText,
              child: Text("Enter Text"),
            ),
            ElevatedButton(
              onPressed: _startNFCProcess,
              child: Text("Start NFC Process"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final imageBytes = await image.readAsBytes();
      setState(() {
        _imageBytes = imageBytes;
        _status = "Image Selected: ${image.name}";
      });
    }
  }

  Future<void> _enterText() async {
    TextEditingController controller = TextEditingController();
    String? enteredText = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Enter Text"),
          content: TextField(controller: controller),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text("Submit"),
            ),
          ],
        );
      },
    );

    if (enteredText != null && enteredText.isNotEmpty) {
      final textImage = await _renderTextToImage(enteredText);
      setState(() {
        _imageBytes = textImage;
        _status = "Text Image Prepared";
      });
    }
  }

  Future<Uint8List> _renderTextToImage(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, 250, 128));
    final textStyle = TextStyle(color: Colors.black, fontSize: 20);
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(minWidth: 0, maxWidth: 250);
    textPainter.paint(canvas, Offset(10, 50));
    final picture = recorder.endRecording();
    final image = await picture.toImage(250, 128);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return Uint8List.fromList(byteData!.buffer.asUint8List());
  }

  Future<void> _startNFCProcess() async {
    try {
      if (_imageBytes == null) {
        setState(() => _status = "No image or text selected");
        return;
      }

      setState(() {
        _status = "Initializing NFC...";
        _progress = 0.0;
      });

      final result = await platform.invokeMethod('startNFCProcess', {
        "imageData": _imageBytes,
      });

      if (result == true) {
        setState(() => _status = "NFC Process Completed");
      } else {
        setState(() => _status = "NFC Process Failed");
      }
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }
}
