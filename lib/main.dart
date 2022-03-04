import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'checkpoint.dart';

Future<List<Checkpoint>> fetchData(http.Client client) async {
  final response = await client.get(Uri.parse(
      'https://raw.githubusercontent.com/Antoni-Czaplicki/jedynka_open_days/main/data/data.json'));
  return compute(parseCheckpoints, response.body);
}

List<Checkpoint> parseCheckpoints(String responseBody) {
  final parsed =
      jsonDecode(responseBody)['checkpoints'].cast<Map<String, dynamic>>();

  return parsed.map<Checkpoint>((json) => Checkpoint.fromJson(json)).toList();
}

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

class InfoPage extends StatelessWidget {
  const InfoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Informacje o aplikacji')),
        body: Center(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/app_icon.png', fit: BoxFit.cover, height: 256),
            const Text('by Antoni Czaplicki'),
            const Text('Wersja aplikacji: TBA')
          ],
        )));
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
        actions: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.info_outline,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InfoPage()),
              );
            },
          )
        ],
      ),
      body: FutureBuilder<List<Checkpoint>>(
        future: fetchData(http.Client()),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('An error has occurred!'),
            );
          } else if (snapshot.hasData) {
            return CheckpointsList(photos: snapshot.data!);
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
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

class CheckpointsList extends StatelessWidget {
  const CheckpointsList({Key? key, required this.photos}) : super(key: key);

  final List<Checkpoint> photos;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: photos.length,
      itemBuilder: (context, index) {
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.network(photos[index].image,
                  fit: BoxFit.cover, height: 200),
              ListTile(
                title: Text(photos[index].title),
                subtitle: Text(photos[index].subtitle),
                leading: const Icon(Icons.check_box_outline_blank),
              ),
            ],
          ),
        );
      },
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
