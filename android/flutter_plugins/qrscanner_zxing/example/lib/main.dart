/*
 * Copyright (C) 2022 Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:qrscanner_zxing/qrscanner_zxing_method_channel.dart';
import 'package:qrscanner_zxing/qrscanner_zxing_view.dart';

import 'cutout_overlay.dart';

void main() {
  runApp(const QRCodeScannerExampleApp());
}

class QRCodeScannerExampleApp extends StatelessWidget {
  const QRCodeScannerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Scanner Example',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const AppHomePage(title: 'QR Scanner Example'),
    );
  }
}

class AppHomePage extends StatelessWidget {
  const AppHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, _, _) => const QRScannerPage(),
                    transitionDuration: const Duration(seconds: 0),
                    reverseTransitionDuration: const Duration(seconds: 0),
                  ),
                );
              },
              child: const Text("Open QR Scanner"),
            ),
            ElevatedButton(
              onPressed: () async {
                var channel = MethodChannelQRScannerZxing();
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final result = await FilePicker.platform.pickFiles(
                  allowedExtensions: ['png', 'jpg', 'gif', 'webp'],
                  type: FileType.custom,
                  allowMultiple: false,
                  lockParentWindow: true,
                  withData: true,
                  dialogTitle: 'Select file with QR code',
                );

                if (result == null || !result.isSinglePick) {
                  // no result
                  return;
                }

                final bytes = result.files.first.bytes;
                if (bytes != null) {
                  var value = await channel.scanBitmap(bytes);
                  final snackBar = SnackBar(
                    content: Text(
                      value == null ? 'No QR code detected' : 'QR: $value',
                    ),
                  );
                  scaffoldMessenger.showSnackBar(snackBar);
                } else {
                  // no files selected
                }
              },
              child: const Text("Scan from file"),
            ),
          ],
        ),
      ),
    );
  }
}

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  QRScannerPageState createState() => QRScannerPageState();
}

class QRScannerPageState extends State<QRScannerPage> {
  String? currentCode;

  QRScannerPageState({Key? key}) : super();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: QRScannerZxingView(
              marginPct: 10,
              onViewInitialized: (permissionsGranted) {
                // this example does not handle Camera permissions
              },
              onDetect: (result) {
                if (currentCode == null) {
                  setState(() {
                    currentCode = result;
                  });
                }
              },
            ),
          ),
          const Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: CutoutOverlay(marginPct: 5),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Back'),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Again"),
                    onPressed: () {
                      setState(() {
                        currentCode = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Card(
              margin: const EdgeInsets.all(20),
              elevation: 100,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text("Found QR code:"),
                    Text(currentCode ?? "NO CODE DETECTED"),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Card(
              margin: EdgeInsets.all(20),
              elevation: 100,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(children: [Text("QR scanner example")]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
