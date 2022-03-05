import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  List<String> completedCheckpoints = [];

  void _loadCompletedCheckpoints() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      completedCheckpoints =
          (prefs.getStringList('completedCheckpoints') ?? []);
    });
  }

  Future<void> _resetCompletedCheckpoints() async {
    SharedPreferences prefs = await _prefs;
    setState(() {
      completedCheckpoints = [];
      prefs.setStringList('completedCheckpoints', completedCheckpoints);
    });
  }

  Future<void> _unlockCheckpoint([String? id]) async {
    SharedPreferences prefs = await _prefs;
    debugPrint(completedCheckpoints.toString());
    setState(() {
      if (id != null && !completedCheckpoints.contains(id)) {
        completedCheckpoints.add(id);
      }
      prefs.setStringList('completedCheckpoints', completedCheckpoints);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCompletedCheckpoints();
  }

  void _scanQRAndUnlockCheckpoint(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScanner()),
    );
    _unlockCheckpoint(result);
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
          ),
          IconButton(
            icon: const Icon(
              Icons.restore,
            ),
            onPressed: () async {
              await _resetCompletedCheckpoints();
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.developer_mode,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..removeCurrentSnackBar()
                ..showSnackBar(
                    SnackBar(content: Text('$completedCheckpoints')));
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
            return CheckpointsList(
              data: snapshot.data!,
              completedCheckpoints: completedCheckpoints,
            );
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
        tooltip: 'Zeskanuj kod QR',
        child: const Icon(Icons.qr_code),
      ),
    );
  }
}

class CheckpointsList extends StatelessWidget {
  const CheckpointsList(
      {Key? key, required this.data, required this.completedCheckpoints})
      : super(key: key);

  final List<Checkpoint> data;
  final List<String> completedCheckpoints;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        return Card(
            child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CheckpointDetails(
                      checkpoint: data[index],
                      isCompleted: completedCheckpoints
                          .contains(data[index].id.toString()))),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image(
                  image: CachedNetworkImageProvider(data[index].image),
                  fit: BoxFit.cover,
                  height: 200),
              ListTile(
                title: Text(data[index].title),
                subtitle: Text(data[index].subtitle),
                leading:
                    completedCheckpoints.contains(data[index].id.toString())
                        ? const Icon(Icons.check_box)
                        : const Icon(Icons.check_box_outline_blank),
              ),
            ],
          ),
        ));
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

class CheckpointDetails extends StatelessWidget {
  const CheckpointDetails(
      {Key? key, required this.checkpoint, required this.isCompleted})
      : super(key: key);
  final Checkpoint checkpoint;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(checkpoint.title)),
        body: ListView(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image(
                  image: CachedNetworkImageProvider(checkpoint.image),
                  fit: BoxFit.cover,
                  height: 300),
              Text(checkpoint.description),
              Text(checkpoint.location),
              isCompleted
                  ? const Icon(Icons.check_box)
                  : const Icon(Icons.check_box_outline_blank),
            ],
          )
        ]));
  }
}
