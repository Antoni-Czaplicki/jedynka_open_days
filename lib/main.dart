import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'checkpoint.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const OpenDaysApp());
}

void _launchURL(String _url) async {
  if (!await launch(_url)) throw 'Could not launch $_url';
}

class Data {
  final int version;
  final int goal;
  final String surveyUrl;
  final List<Checkpoint> checkpoints;

  Data(
      {required this.version,
      required this.goal,
      required this.surveyUrl,
      required this.checkpoints});
}

Future<Data> fetchData(http.Client client) async {
  final response = await client.get(Uri.parse(
      'https://raw.githubusercontent.com/Antoni-Czaplicki/jedynka_open_days/main/data/data.json'));
  return Data(
      version: jsonDecode(response.body)['version'],
      goal: jsonDecode(response.body)['goal'],
      surveyUrl: jsonDecode(response.body)['survey_url'],
      checkpoints: parseCheckpoints(response.body));
}

List<Checkpoint> parseCheckpoints(String responseBody) {
  final parsed =
      jsonDecode(responseBody)['checkpoints'].cast<Map<String, dynamic>>();

  return parsed.map<Checkpoint>((json) => Checkpoint.fromJson(json)).toList();
}

class OpenDaysApp extends StatelessWidget {
  const OpenDaysApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dzień otwarty ILO',
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
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  List<String> completedCheckpoints = [];

  void _loadCompletedCheckpoints() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      completedCheckpoints =
          (prefs.getStringList('completedCheckpoints') ?? []);
    });
  }

  // Future<void> _resetCompletedCheckpoints() async {
  //   SharedPreferences prefs = await _prefs;
  //   setState(() {
  //     completedCheckpoints = [];
  //     prefs.setStringList('completedCheckpoints', completedCheckpoints);
  //   });
  // }

  Future<void> _unlockCheckpoint([String? id]) async {
    SharedPreferences prefs = await _prefs;
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

  void _scanQRAndUnlockCheckpoint(BuildContext context,
      [List<Checkpoint>? checkpoints]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScanner()),
    );
    if (result == null) return;
    if (checkpoints != null) {
      var checkpoint = checkpoints
          .firstWhereOrNull((element) => element.id.toString() == result);
      if (checkpoint != null) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Zatwierdzono "${checkpoint.title}"'),
            action: SnackBarAction(
              label: 'Otwórz',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CheckpointDetails(
                          checkpoint: checkpoint, isCompleted: true)),
                );
              },
            ),
          ));
      } else {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Zeskanowano nieznany kod ($result)'),
          ));
      }
    } else {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Zeskanowano nieznany kod QR'),
        ));
    }
    _unlockCheckpoint(result);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Data>(
        future: fetchData(http.Client()),
        builder: (context, snapshot) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(
                    Icons.redeem,
                  ),
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return const AlertDialog(
                            title: Text('Nagroda'),
                            content: Placeholder(),
                          );
                        });
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.emoji_emotions_outlined,
                  ),
                  onPressed: () async {
                    if (snapshot.hasError) {
                      ScaffoldMessenger.of(context)
                        ..removeCurrentSnackBar()
                        ..showSnackBar(
                            const SnackBar(content: Text('Brak internetu')));
                    } else if (snapshot.hasData) {
                      _launchURL(snapshot.data!.surveyUrl);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.info_outline,
                  ),
                  onPressed: () {
                    var dbVersion = snapshot.data?.version;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => InfoPage(dbVersion: dbVersion)),
                    );
                  },
                ),
              ],
            ),
            body: checkpointsList(snapshot),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                _scanQRAndUnlockCheckpoint(
                    context,
                    !snapshot.hasError && snapshot.hasData
                        ? snapshot.data!.checkpoints
                        : null);
              },
              tooltip: 'Zeskanuj kod QR',
              child: const Icon(Icons.qr_code),
            ),
          );
        });
  }

  Builder checkpointsList(AsyncSnapshot<Data> snapshot) {
    return Builder(
      builder: (context) {
        if (snapshot.hasError) {
          return networkErrorWidget(context);
        } else if (snapshot.hasData) {
          var checkpoints = snapshot.data!.checkpoints;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              itemCount: checkpoints.length,
              itemBuilder: (context, index) {
                return Card(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckpointDetails(
                            checkpoint: checkpoints[index],
                            isCompleted: completedCheckpoints
                                .contains(checkpoints[index].id.toString()),
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Hero(
                          tag: checkpoints[index].id,
                          child: Image(
                              image: CachedNetworkImageProvider(
                                  checkpoints[index].image),
                              fit: BoxFit.cover,
                              height: 200),
                        ),
                        ListTile(
                            title: Text(checkpoints[index].title),
                            subtitle: Text(checkpoints[index].subtitle),
                            leading: Hero(
                              tag: checkpoints[index].id.toString() +
                                  '_check_box',
                              child: completedCheckpoints.contains(
                                      checkpoints[index].id.toString())
                                  ? const Icon(Icons.check_box)
                                  : const Icon(Icons.check_box_outline_blank),
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }

  RefreshIndicator networkErrorWidget(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height -
              AppBar().preferredSize.height,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Brak połączenia z internetem'),
              ElevatedButton(
                onPressed: () {
                  setState(() {});
                },
                child: const Text('Odśwież'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class InfoPage extends StatelessWidget {
  const InfoPage({Key? key, required this.dbVersion}) : super(key: key);
  final int? dbVersion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informacje o aplikacji')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              child: Image.asset('assets/app_icon.png',
                  fit: BoxFit.cover, height: 256),
            ),
            Text('\nWersja bazy danych: ${dbVersion.toString()}')
          ],
        ),
      ),
    );
  }
}

class QRScanner extends StatelessWidget {
  const QRScanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zeskanuj kod QR')),
      body: MobileScanner(onDetect: (barcode, args) {
        final String? code = barcode.rawValue;
        debugPrint('QR code found! $code');
        Navigator.pop(context, code);
      }),
    );
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
              Hero(
                tag: checkpoint.id,
                child: Image(
                    image: CachedNetworkImageProvider(checkpoint.image),
                    fit: BoxFit.cover,
                    height: 300),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Text(checkpoint.description),
              ),
              Text(checkpoint.location),
              Hero(
                tag: checkpoint.id.toString() + '_check_box',
                child: isCompleted
                    ? const Icon(Icons.check_box)
                    : const Icon(Icons.check_box_outline_blank),
              )
            ],
          )
        ]));
  }
}
