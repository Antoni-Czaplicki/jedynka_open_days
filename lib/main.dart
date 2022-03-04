import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const OpenDaysApp());
}

class OpenDaysApp extends StatelessWidget {
  const OpenDaysApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dni Otwarte ILO',
      theme: ThemeData(
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(title: 'Dzień otwarty ILO'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var completedCheckpoints = '';

  void _scanQRAndUnlockCheckpoint(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScanner()),
    );
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$result')));
    setState(() {
      completedCheckpoints += '$result ';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Zeskanowane kody:',
            ),
            Text(
              completedCheckpoints,
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scanQRAndUnlockCheckpoint(context);
        },
        tooltip: 'Skanuj kod',
        child: const Icon(Icons.qr_code),
      ),
    );
  }
}

class QRScanner extends StatelessWidget {
  const QRScanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      var scanned = false;
      return Scaffold(
        appBar: AppBar(title: const Text('Zeskanuj kod QR')),
        body: MobileScanner(onDetect: (barcode, args) {
          if (!scanned) {
            final String? code = barcode.rawValue;
            debugPrint('QR code found! $code');
            scanned = true;
            Navigator.pop(context, code);
          }
        }),
      );
    } else {
      return Scaffold(
          appBar: AppBar(title: const Text('Web scanner')),
          body: const Center(
            child: Text('Not implemented yet'),
          ));
    }
  }
}
