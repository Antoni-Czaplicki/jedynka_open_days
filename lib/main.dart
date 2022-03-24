import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
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
  final String rewardDescription;
  final List<Checkpoint> checkpoints;

  Data(
      {required this.version,
      required this.goal,
      required this.surveyUrl,
      required this.rewardDescription,
      required this.checkpoints});
}

Future<Data> fetchData(http.Client client) async {
  final response = await client.get(Uri.parse(
      'https://raw.githubusercontent.com/Antoni-Czaplicki/jedynka_open_days/main/data/data.json'));
  return Data(
      version: jsonDecode(response.body)['version'],
      goal: jsonDecode(response.body)['goal'],
      surveyUrl: jsonDecode(response.body)['survey_url'],
      rewardDescription: jsonDecode(response.body)['reward_description'],
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
  bool isLocked = false;

  void _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      completedCheckpoints =
          (prefs.getStringList('completedCheckpoints') ?? []);
      isLocked = (prefs.getBool('isLocked') ?? false);
    });
  }

  Future<void> _unlockCheckpoint([String? id]) async {
    SharedPreferences prefs = await _prefs;
    setState(() {
      if (id != null && !completedCheckpoints.contains(id)) {
        completedCheckpoints.add(id);
      }
      prefs.setStringList('completedCheckpoints', completedCheckpoints);
    });
  }

  Future<void> _lockReward() async {
    SharedPreferences prefs = await _prefs;
    setState(() {
      isLocked = true;
      prefs.setBool('isLocked', isLocked);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSavedData();
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
                (snapshot.data?.goal != -1)
                    ? rewardIconButton(snapshot, context)
                    : const SizedBox.shrink(),
                surveyIconButton(snapshot, context),
                infoPageIconButton(snapshot, context),
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

  IconButton rewardIconButton(
      AsyncSnapshot<Data> snapshot, BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.card_giftcard,
      ),
      onPressed: () {
        if (!snapshot.hasError && snapshot.hasData) {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                List<String> validCompletedCheckpoints = [];
                if (snapshot.hasData) {
                  for (final checkpoint in completedCheckpoints) {
                    if (snapshot.data!.checkpoints
                        .map((item) => item.id.toString())
                        .contains(checkpoint)) {
                      validCompletedCheckpoints.add(checkpoint);
                    }
                  }
                }
                return AlertDialog(
                  title: const Text('Odbierz nagrodę'),
                  content: Text(snapshot.hasData
                      ? "${snapshot.data?.rewardDescription}\n\nZaliczone punkty: ${validCompletedCheckpoints.length.toString()}/${snapshot.data!.goal.toString()} (${(validCompletedCheckpoints.length / snapshot.data!.goal * 100).round()}%)"
                      : "Brak internetu"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'Cancel'),
                      child: const Text('Anuluj'),
                    ),
                    (validCompletedCheckpoints.length >= snapshot.data!.goal &&
                            !isLocked)
                        ? TextButton(
                            child: const Text("Odbierz"),
                            onPressed: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text("Odbierz nageodę"),
                                    content: const Text(
                                        "Potwierdź odebranie nagrody. Spowoduje to zablokowanie aplikacji"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, 'Cancel'),
                                        child: const Text('Anuluj'),
                                      ),
                                      TextButton(
                                          onPressed: () {
                                            _lockReward();
                                            Navigator.pop(context);
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: const Text("Nagroda"),
                                                  content: Container(
                                                    width: 200.0,
                                                    height: 200.0,
                                                    alignment: Alignment.center,
                                                    child: QrImage(
                                                      data:
                                                          "Nagroda - ${validCompletedCheckpoints.length} pkt.",
                                                      version: QrVersions.auto,
                                                      backgroundColor:
                                                          Colors.white,
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, 'OK'),
                                                      child: const Text('Ok'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          child: const Text("Odbierz nagrodę")),
                                    ],
                                  );
                                },
                              );
                            })
                        : !isLocked
                            ? const TextButton(
                                onPressed: null,
                                child: Text(
                                    "Za mało punktów aby\nodebrać nagrodę"))
                            : const TextButton(
                                onPressed: null,
                                child: Text("Odebrałeś już nagrodę"))
                  ],
                );
              });
        } else {
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Brak internetu')));
        }
      },
    );
  }

  IconButton infoPageIconButton(
      AsyncSnapshot<Data> snapshot, BuildContext context) {
    return IconButton(
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
    );
  }

  IconButton surveyIconButton(
      AsyncSnapshot<Data> snapshot, BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.emoji_emotions_outlined,
      ),
      onPressed: () async {
        if (snapshot.hasError) {
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Brak internetu')));
        } else if (snapshot.hasData) {
          _launchURL(snapshot.data!.surveyUrl);
        }
      },
    );
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
              itemCount: checkpoints.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScheduleDetails(
                                events: checkpoints,
                                completedCheckpoints: completedCheckpoints),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: const <Widget>[
                          Hero(
                            tag: "schedule",
                            child: Image(
                                image: CachedNetworkImageProvider(
                                    "https://raw.githubusercontent.com/Antoni-Czaplicki/jedynka_open_days/main/data/images/schedule.png"),
                                fit: BoxFit.cover,
                                height: 300),
                          ),
                          ListTile(
                            title: Text("Plan dnia otwartego"),
                            subtitle: Text("Co, gdzie, kiedy i jak?"),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckpointDetails(
                              checkpoint: checkpoints[index - 1],
                              isCompleted: completedCheckpoints.contains(
                                  checkpoints[index - 1].id.toString()),
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Hero(
                            tag: checkpoints[index - 1].id,
                            child: Image(
                                image: CachedNetworkImageProvider(
                                    checkpoints[index - 1].image),
                                fit: BoxFit.cover,
                                height: 200),
                          ),
                          ListTile(
                              title: Text(checkpoints[index - 1].title),
                              subtitle: Text(checkpoints[index - 1].subtitle),
                              enabled: completedCheckpoints.contains(
                                  checkpoints[index - 1].id.toString()),
                              trailing: Hero(
                                tag: checkpoints[index - 1].id.toString() +
                                    '_check_box',
                                child: completedCheckpoints.contains(
                                        checkpoints[index - 1].id.toString())
                                    ? const Icon(Icons.check_box)
                                    : const Icon(Icons.check_box_outline_blank),
                              )),
                        ],
                      ),
                    ),
                  );
                }
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
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.keyboard),
        tooltip: "Wpisz kod",
        onPressed: () {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                TextEditingController _textFieldController =
                    TextEditingController();
                String? code;
                return AlertDialog(
                  title: const Text("Wprowdź kod punktu"),
                  content: TextField(
                    onChanged: (value) {
                      code = value;
                    },
                    controller: _textFieldController,
                    decoration: const InputDecoration(hintText: "Kod"),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Anuluj'),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                    ),
                    TextButton(
                      child: const Text('Zatwierdź'),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context, code);
                      },
                    ),
                  ],
                );
              });
        },
      ),
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
              Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    ListTile(
                      title: Text(checkpoint.title),
                      subtitle: Text(checkpoint.description),
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 28,
                      ),
                      title: Text(
                        checkpoint.location,
                        style: const TextStyle(fontSize: 20),
                      ),
                      trailing: Hero(
                        tag: checkpoint.id.toString() + '_check_box',
                        child: isCompleted
                            ? const Icon(Icons.check_box)
                            : const Icon(Icons.check_box_outline_blank),
                      ),
                    ),
                  ]))
            ],
          )
        ]));
  }
}

class ScheduleDetails extends StatelessWidget {
  const ScheduleDetails(
      {Key? key, required this.events, required this.completedCheckpoints})
      : super(key: key);
  final List<Checkpoint> events;
  final List<String> completedCheckpoints;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Plan dnia otwartego")),
        body: ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CheckpointDetails(
                          checkpoint: events[index],
                          isCompleted: completedCheckpoints
                              .contains(events[index].id.toString()),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: ListTile(
                      dense: true,
                      leading: Text(events[index].time),
                      title: Text(
                        events[index].title,
                        style: const TextStyle(fontSize: 20),
                      ),
                      trailing: Text(events[index].location),
                    ),
                  ));
            }));
  }
}
