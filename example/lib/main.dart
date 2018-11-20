import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

enum loadState {
  running,
  success,
  failed
}

class _MyAppState extends State<MyApp> {
  File _image;
  List _recognitions;
  loadState _loading = loadState.running;

  Future getImage() async {
    if(_loading != loadState.success)
      return;
    var image = await ImagePicker.pickImage(source: ImageSource.camera);
    recognizeImage(image);
    setState(() {
      _image = image;
    });
  }

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<String> _downloadFile(String url, String filename) async {
    String dir = Directory.systemTemp.path;
    String filePath = '$dir/$filename';
    bool localExists = await File(filePath).exists();
    if(localExists)
      return filePath;

    http.Client _client = new http.Client();
    var req = await _client.get(Uri.parse(url));
    var bytes = req.bodyBytes;
    
    File file = new File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  Future loadModel() async {
    try {
      String modelPath = await _downloadFile('https://raw.githubusercontent.com/googlecodelabs/tensorflow-for-poets-2/master/android/tflite/app/src/main/assets/graph.lite', 'graph.lite');
      String labelsPath = await _downloadFile('https://raw.githubusercontent.com/googlecodelabs/tensorflow-for-poets-2/master/android/tflite/app/src/main/assets/labels.txt', 'labels.txt');

      String res = await Tflite.loadModel(
        model: modelPath,
        labels: labelsPath,
      );
      print('model load result: $res');
      if(res == 'success')
        setState((){ _loading = loadState.success; });
      else
        setState((){ _loading = loadState.failed; });
    } catch(e) {
      print('Failed to load model. $e');
      setState((){ _loading = loadState.failed; });
    }
  }

  // Future loadModelFromAssets() async {
  //   try {
  //     String res = await Tflite.loadModelFromAssets(
  //       model: "assets/mobilenet_v1_1.0_224.tflite",
  //       labels: "assets/labels.txt",
  //     );
  //     print(res);
  //   } on PlatformException {
  //     print('Failed to load model.');
  //   }
  // }

  Future recognizeImage(File image) async {
    var recognitions = await Tflite.runModelOnImage(
      path: image.path,
      numResults: 6,
      threshold: 0.05,
    );
    print(recognitions);
    setState(() {
      _recognitions = recognitions;
    });
    // await Tflite.close();
  }

  Widget _buildMessage() {
    switch(_loading) {
      case loadState.running:
        return Text('Model downloading...');
      case loadState.success:
        return Text('Model downloaded successfully. Please pick an image.');
      case loadState.failed:
        return Text('Model download failed.');
    }
    
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('tflite example app'),
        ),
        body: Stack(
          children: <Widget>[
            Center(
              child: _image == null
                  ? _buildMessage()
                  : Image.file(_image),
            ),
            Center(
              child: Column(
                children: _recognitions != null
                    ? _recognitions.map((res) {
                        return Text(
                          "${res["index"]} - ${res["label"]}: ${res["confidence"].toString()}",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20.0,
                            background: Paint()..color = Colors.white,
                          ),
                        );
                      }).toList()
                    : [],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: getImage,
          tooltip: 'Pick Image',
          child: Icon(Icons.add_a_photo),
        ),
      ),
    );
  }
}
