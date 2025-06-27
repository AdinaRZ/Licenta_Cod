import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'main.dart';
import 'temperature_chart_screen.dart';
import 'humidity_chart_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'system_log_screen.dart';
import 'user_settings_screen.dart';
import 'profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_form.dart';
import 'outdoor_temperature_chart_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLight1On = false;
  bool _isLight2On = false;
  bool _isWindow1Open = false;
  bool _isWindow2Open = false;
  bool _accessGranted = true;
  bool _isRaining = false;
  double _outdoorTemp = 0;
  double _indoorTemp = 0;
  double _humidity = 0;
  bool _overrideRainProtection = false;
  final DatabaseReference _database = rtdb;

  bool _isDetailedView = true;
  List<String> _systemLog = [];
  bool _showSystemLog = false;

  Timer? _accessTimer;
  int _secondsLeft = 0;

  String _currentUsername = '';
  late List<Map<String, dynamic>> _widgets;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }


  List<FlSpot> _generateMiniSparkline() {
    final random = Random();
    return List.generate(
      7,
          (i) => FlSpot(i.toDouble(), 40 + random.nextDouble() * 30),
    );
  }

  Future<bool> _confirmWindowOpenOnRain() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atenție!'),
        content:
        const Text('Plouă afară. Ești sigur că vrei să deschizi geamurile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anulează'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Da'),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<void> abonareLaCasa() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final snapshot = await FirebaseDatabase.instance.ref("users/$uid/codCasa").get();
      if (snapshot.exists) {
        final codCasa = snapshot.value.toString();
        await FirebaseMessaging.instance.subscribeToTopic(codCasa);
        print("Abonat la topic: $codCasa");
      }
    }
  }

  void _sendAccessNotification() async {
    print('Trimit notificare de acces!');
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'acces_channel', // id canal
      'Acces Alert', // nume canal
      channelDescription: 'Notificare când se acordă acces în casă',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Atenție!',
      'Cineva a primit acces în casa ta!',
      platformChannelSpecifics,
    );
  }


  Future<void> _loadUserData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance.collection('utilizatori').doc(uid).get();
      final data = doc.data();
      if (data != null && data.containsKey('username')) {
        setState(() {
          _currentUsername = data['username'];
        });
      }
    } catch (e) {
      print('Eroare la încărcarea datelor utilizatorului: $e');
    }
  }

  Future<void> _loadInitialStatesFromFirebase() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance.collection('utilizatori').doc(uid).get();
      final codCasa = doc.data()?['codCasa'];
      if (codCasa == null) return;

      final snapshot = await _database.child('case').child(codCasa).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map;
        setState(() {
          _isLight1On = data['bec1'] ?? false;
          _isLight2On = data['bec2'] ?? false;
          _isWindow1Open = data['geam1'] ?? false;
          _isWindow2Open = data['geam2'] ?? false;
          _indoorTemp = (data['temperatura_interior'] ?? 0).toDouble();
          _outdoorTemp = (data['temperatura_exterior'] ?? 0).toDouble();
          _accessGranted = data['acces'] ?? false;
          _isRaining = data['ploua'] ?? false;
          _humidity = (data['umiditate'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      print('Eroare la citirea stărilor inițiale: $e');
    }
  }

  void _listenToRealtimeUpdates() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('utilizatori').doc(uid).get();
    final codCasa = doc.data()?['codCasa'];
    if (codCasa == null) return;

    _database.child('case').child(codCasa).onValue.listen((event) async {
      final data = event.snapshot.value as Map?;

      if (data != null) {
        final newRainStatus = data['ploua'] ?? false;

        if (newRainStatus == true && (_isWindow1Open || _isWindow2Open)) {
          if (!_overrideRainProtection) {
            await _database.child('case').child(codCasa).update({
              'geam1': false,
              'geam2': false,
            });
            setState(() {
              _isWindow1Open = false;
              _isWindow2Open = false;
            });
            _addLog('Geamurile au fost închise automat din cauza ploii.');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Geamurile au fost închise automat din cauza ploii!'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }

        setState(() {
          _isLight1On = data['bec1'] ?? false;
          _isLight2On = data['bec2'] ?? false;
          _isWindow1Open = data['geam1'] ?? false;
          _isWindow2Open = data['geam2'] ?? false;
          _indoorTemp = (data['temperatura_interior'] ?? 0).toDouble();
          _outdoorTemp = (data['temperatura_exterior'] ?? 0).toDouble();
          final newAccess = data['acces'] ?? false;

          if (newAccess && !_accessGranted) {
            _sendAccessNotification();
          }

          _accessGranted = newAccess;

          _isRaining = newRainStatus;
          _humidity = (data['umiditate'] ?? 0).toDouble();
        });
      }
    });
  }

  Future<void> _requestNotificationPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _updateWindowState(String windowKey, bool newValue) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('utilizatori').doc(uid).get();
      final codCasa = doc.data()?['codCasa'];
      if (codCasa != null) {
        await _database.child('case').child(codCasa).child(windowKey).set(newValue);
      }
    }

    setState(() {
      if (windowKey == 'geam1') {
        _isWindow1Open = newValue;
      } else {
        _isWindow2Open = newValue;
      }
    });
  }

  void _startAccessCountdown(String codCasa) {
    // daca exista un timer activ, se opreste
    _accessTimer?.cancel();
    _secondsLeft = 30;

    _accessTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();

        // Firebase: acces = false
        await _database.child('case').child(codCasa).child('acces').set(false);
        setState(() {
          _accessGranted = false;
          _secondsLeft = 0;
          _addLog('Accesul a fost blocat automat după 30 secunde');
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accesul a fost blocat automat după 30 secunde'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    abonareLaCasa();
    _initializeNotifications();
    _requestNotificationPermissions();
    _setupFCMListeners();
    _loadUserData();
    _loadInitialStatesFromFirebase();
    _listenToRealtimeUpdates();
    // Incarca username-ul din Firestore
    _loadUserData();
    _loadInitialStatesFromFirebase();
    _listenToRealtimeUpdates();
    // Initializeaza cardurile UI
    _widgets = [
      {
        'key': 'temperature',
        'builder': () => _buildTappableTile(
          context,
          title: 'Temperatură',
          icon: Icons.thermostat,
          destination: const TemperatureChartScreen(),
          miniData: _generateMiniSparkline(),
          color: Colors.orange,
          isDetailed: _isDetailedView,
          currentValue: _indoorTemp,
          unit: '°C',
        ),
      },
      {
        'key': 'outdoor_temp',
        'builder': () => _buildTappableTile(
          context,
          title: 'Temperatura de afară',
          icon: Icons.thermostat_auto,
          destination: const OutdoorTemperatureChartScreen(),
          miniData: _generateMiniSparkline(),
          color: Colors.pinkAccent,
          isDetailed: _isDetailedView,
          currentValue: _outdoorTemp,
          unit: '°C',
        ),
      },
      {
        'key': 'humidity',
        'builder': () => _buildTappableTile(
          context,
          title: 'Umiditate',
          icon: Icons.water_drop,
          destination: const HumidityChartScreen(),
          miniData: _generateMiniSparkline(),
          color: Colors.teal,
          isDetailed: _isDetailedView,
          currentValue: _humidity,
          unit: '%',
        ),
      },
      {
        'key': 'light1',
        'builder': () => _buildSwitchTile(
          title: 'Bec1',
          value: _isLight1On,
          icon: Icons.lightbulb,
          onChanged: (val) async {
            setState(() => _isLight1On = val);

            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              final doc = await FirebaseFirestore.instance.collection('utilizatori').doc(uid).get();
              final codCasa = doc.data()?['codCasa'];

              if (codCasa != null) {
                await _database.child('case').child(codCasa).child('bec1').set(val);
              }
            }
          },
          feedbackMessageOn: 'Bec aprins',
          feedbackMessageOff: 'Bec stins',
        ),
      },
      {
        'key': 'light2',
        'builder': () => _buildSwitchTile(
          title: 'Bec2',
          value: _isLight2On,
          icon: Icons.lightbulb,
          onChanged: (val) async {
            setState(() => _isLight2On = val);

            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              final doc = await FirebaseFirestore.instance.collection('utilizatori').doc(uid).get();
              final codCasa = doc.data()?['codCasa'];

              if (codCasa != null) {
                await _database.child('case').child(codCasa).child('bec2').set(val);
              }
            }
          },
          feedbackMessageOn: 'Bec aprins',
          feedbackMessageOff: 'Bec stins',
        ),
      },
      {
        'key': 'window1',
        'builder': () => _buildSwitchTile(
          title: 'Geam1',
          value: _isWindow1Open,
          icon: Icons.window,
          onChanged: (val) async {
            if (_isRaining && val) {
              final confirm = await _confirmWindowOpenOnRain();
              if (!confirm) return;
              _overrideRainProtection = true;
            }
            await _updateWindowState('geam1', val);
            setState(() {
              _overrideRainProtection = false;
            });
          },
          feedbackMessageOn: 'Geamurile au fost deschise',
          feedbackMessageOff: 'Geamurile au fost inchise',
        ),
      },
      {
        'key': 'window2',
        'builder': () => _buildSwitchTile(
          title: 'Geam2',
          value: _isWindow2Open,
          icon: Icons.window,
          onChanged: (val) async {
            if (_isRaining && val) {
              final confirm = await _confirmWindowOpenOnRain();
              if (!confirm) return;
              _overrideRainProtection = true;
            }
            await _updateWindowState('geam2', val);
            setState(() {
              _overrideRainProtection = false;
            });
          },
          feedbackMessageOn: 'Geamurile au fost deschise',
          feedbackMessageOff: 'Geamurile au fost inchise',
        ),
      },
      {
        'key': 'access',
        'builder': () => _buildInfoTile(
          'Acces',
          _accessGranted ? 'Permis' : 'Refuzat',
          _accessGranted ? Icons.lock_open : Icons.lock,
          isDetailed: _isDetailedView,
        ),
      },
      {
        'key': 'rain',
        'builder': () => _buildInfoTile(
          'Ploaie',
          _isRaining ? 'Plouă' : 'Nu plouă',
          _isRaining ? Icons.umbrella : Icons.cloud_queue,
          isDetailed: _isDetailedView,
        ),
      },
    ];
  }

  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel',
              'Notificări Smart Home',
              channelDescription: 'Afișează notificări despre acces, geamuri etc.',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
        );
      }
    });
  }


  Widget _buildTappableTile(BuildContext context, {
    required String title,
    required IconData icon,
    required Widget destination,
    required List<FlSpot> miniData,
    required bool isDetailed,
    Color color = Colors.blueAccent,
    double? currentValue,
    String? unit,
  }) {
    return Card(
      key: ValueKey(title),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: isDetailed
            ? SizedBox(
          height: 50,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(show: false),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: miniData,
                  isCurved: true,
                  color: color,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                  barWidth: 2,
                ),
              ],
            ),
          ),
        )
            : (currentValue != null && unit != null)
            ? Text(
          '${currentValue.toStringAsFixed(1)}$unit',
          style: TextStyle(
            fontSize: 14,
            color: title.contains('afară') ? Colors.black : Colors.black,
          ),
        )
            : null,


        trailing: isDetailed ? const Icon(Icons.arrow_forward_ios) : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        },
      ),
    );
  }

  void _addLog(String message) {
    setState(() {
      _systemLog.insert(0, '${DateTime
          .now()
          .hour
          .toString()
          .padLeft(2, '0')}:${DateTime
          .now()
          .minute
          .toString()
          .padLeft(2, '0')} - $message');
      if (_systemLog.length > 20) {
        _systemLog.removeLast();
      }
    });
  }

  Widget _buildSystemLogCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: SizedBox(
        height: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Jurnalul sistemului',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                itemCount: _systemLog.length,
                itemBuilder: (context, index) {
                  return Text(
                    '• ${_systemLog[index]}',
                    style: const TextStyle(fontSize: 13),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon,
      {bool isDetailed = true}) {
    final bool isRainCard = title == 'Ploaie';
    final bool isAccessCard = title == 'Acces';

    return Card(
      key: ValueKey(title),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: isDetailed && isAccessCard
          ? (_accessGranted ? Colors.green[50] : Colors.red[50])
          : (isDetailed && isRainCard
          ? (_isRaining ? Colors.blue[50] : Colors.grey[100])
          : Colors.white),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                icon,
                color: isDetailed
                    ? (isAccessCard
                    ? (_accessGranted ? Colors.green : Colors.red)
                    : (isRainCard
                    ? (_isRaining ? Colors.blue : Colors.grey)
                    : Colors.blueAccent))
                    : Colors.blueAccent,
                size: isDetailed ? 36 : 28,
              ),
              title: Text(title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value),
                  if (isDetailed && isAccessCard) ...[
                    const SizedBox(height: 4),
                    Text(
                      _accessGranted
                          ? 'Acces permis prin card.'
                          : 'Accesul este blocat momentan.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  if (isDetailed && isAccessCard && _accessGranted && _secondsLeft > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Timp rămas: $_secondsLeft secunde',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                  if (isDetailed && isRainCard) ...[
                    const SizedBox(height: 4),
                    Text(
                      _isRaining
                          ? 'Atenție! Se recomandă închiderea geamurilor.'
                          : 'Vreme bună – geamurile pot rămâne deschise.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),

              trailing: const Icon(Icons.drag_handle),
            ),

            // Buton pentru acces
            if (isDetailed && isAccessCard)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      setState(() {
                        _accessGranted = !_accessGranted;
                        _addLog(_accessGranted
                            ? 'Accesul a fost permis'
                            : 'Accesul a fost blocat');
                      });

                      // Scriere in Firebase
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        final doc = await FirebaseFirestore.instance
                            .collection('utilizatori')
                            .doc(uid)
                            .get();
                        final codCasa = doc.data()?['codCasa'];
                        if (codCasa != null) {
                          await _database
                              .child('case')
                              .child(codCasa)
                              .child('acces')
                              .set(_accessGranted);

                          if (_accessGranted) {
                            _startAccessCountdown(codCasa); // pornește timerul de 30 de secunde
                          } else {
                            _accessTimer?.cancel();         // oprește timerul dacă se blochează manual
                            setState(() => _secondsLeft = 0);
                          }

                        }
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_accessGranted
                              ? 'Accesul a fost permis!'
                              : 'Accesul a fost blocat!'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icon(
                        _accessGranted ? Icons.lock : Icons.lock_open),
                    label: Text(_accessGranted
                        ? 'Blochează'
                        : 'Permite accesul'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accessGranted
                          ? Colors.redAccent
                          : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),

            // Buton pentru inchiderea geamurilor daca ploua
            if (isDetailed && isRainCard && _isRaining && (_isWindow1Open || _isWindow2Open))
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    setState(() {
                      _isWindow1Open = false;
                      _isWindow2Open = false;
                    });

                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      final doc = await FirebaseFirestore.instance.collection('utilizatori').doc(uid).get();
                      final codCasa = doc.data()?['codCasa'];
                      if (codCasa != null) {
                        await _database.child('case').child(codCasa).update({
                          'geam1': false,
                          'geam2': false,
                        });
                      }
                    }
                    // Resetare valoare de protectie dupa ce s-au deschis
                    setState(() {
                      _overrideRainProtection = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Geamurile au fost închise din cauza ploii!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },

                  icon: const Icon(Icons.close),
                  label: const Text('Închide geamurile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    String? feedbackMessageOn,
    String? feedbackMessageOff,
  }) {
    return Card(
      key: ValueKey(title),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Colors.white,
      child: ListTile(
        leading: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Icon(
            icon == Icons.window ? Icons.sensor_window : icon,
            key: ValueKey('$title-$value'),
            color: icon == Icons.window
                ? (value ? Colors.lightBlue : Colors.grey)
                : (icon == Icons.lightbulb
                ? (value ? Colors.amber : Colors.grey)
                : Colors.blueAccent),
            size: 28,
          ),
        ),

        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: value,
              onChanged: (val) {
                onChanged(val); // actualizeaza valoarea
                _addLog(val
                    ? (feedbackMessageOn ?? '$title activat')
                    : (feedbackMessageOff ?? '$title dezactivat'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      val ? (feedbackMessageOn ?? '') : (feedbackMessageOff ??
                          ''),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },

            ),

            const Icon(Icons.drag_handle),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    String message = 'Sistemul funcționează normal';
    Color backgroundColor = Colors.green[100]!;
    Color textColor = Colors.green[800]!;
    IconData icon = Icons.check_circle;

    if (_isRaining && (_isWindow1Open || _isWindow2Open)) {
      message = 'Avertizare: Plouă, geamurile sunt deschise!';
      backgroundColor = Colors.orange[100]!;
      textColor = Colors.orange[900]!;
      icon = Icons.warning_amber_rounded;
    } else if (!_accessGranted) {
      message = 'Accesul este blocat în sistem.';
      backgroundColor = Colors.blueGrey[100]!;
      textColor = Colors.blueGrey[800]!;
      icon = Icons.lock_outline;
    } else if (_isLight1On || _isLight2On) {
      message = 'Lumina este aprinsă – verifică necesitatea.';
      backgroundColor = Colors.yellow[100]!;
      textColor = Colors.orange[800]!;
      icon = Icons.lightbulb;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: backgroundColor,
      child: ListTile(
        leading: Icon(icon, color: textColor, size: 32),
        title: Text(
          message,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _accessTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Home'),
        backgroundColor: const Color(0xFFa1c4fd),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],

      ),
      endDrawer: _buildEndDrawer(),
      body: Column(
        children: [
          _buildSystemStatusCard(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Simplu'),
                Switch(
                  value: _isDetailedView,
                  onChanged: (val) {
                    setState(() => _isDetailedView = val);
                  },
                ),
                const Text('Detaliat'),
              ],
            ),
          ),

          if (_showSystemLog) ...[_buildSystemLogCard()],

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    setState(() {
                      _isLight1On = false;
                      _isLight2On = false;
                    });

                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      final doc = await FirebaseFirestore.instance.collection('utilizatori').doc(uid).get();
                      final codCasa = doc.data()?['codCasa'];
                      if (codCasa != null) {
                        await _database.child('case').child(codCasa).update({
                          'bec1': false,
                          'bec2': false,
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Stinge luminile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (_isRaining) {
                      final confirm = await _confirmWindowOpenOnRain();
                      if (!confirm) return;
                      _overrideRainProtection = true;
                    }

                    setState(() {
                      _isWindow1Open = true;
                      _isWindow2Open = true;
                    });

                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      final doc = await FirebaseFirestore.instance.collection('utilizatori').doc(uid).get();
                      final codCasa = doc.data()?['codCasa'];
                      if (codCasa != null) {
                        await _database.child('case').child(codCasa).update({
                          'geam1': true,
                          'geam2': true,
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.window),
                  label: const Text('Deschide geamurile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.all(16),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _widgets.removeAt(oldIndex);
                  _widgets.insert(newIndex, item);
                });
              },
              children: _widgets.map((widgetMap) {
                return Container(
                  key: ValueKey(widgetMap['key']),
                  child: widgetMap['builder'](),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEndDrawer() {
    if (_currentUsername.isEmpty) {
      return const Drawer(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFFa1c4fd)),
            child: Text(
              'Meniu',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profil'),
            onTap: () async {
              Navigator.pop(context);

              final uid = FirebaseAuth.instance.currentUser!.uid;
              final doc = await FirebaseFirestore.instance.collection('utilizatori').doc(uid).get();
              final data = doc.data();

              if (data != null) {
                final String username = data['username'];
                final String role = data['role'];
                final String homeCode = data['codCasa'];

                List<String> locatari = [];

                if (role == 'proprietar') {
                  final snapshot = await FirebaseFirestore.instance
                      .collection('utilizatori')
                      .where('codCasa', isEqualTo: homeCode)
                      .where('role', isEqualTo: 'locatar')
                      .get();

                  locatari = snapshot.docs.map((e) => e['username'] as String).toList();
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      username: username,
                      role: role,
                      homeCode: homeCode,
                      locatari: locatari,
                    ),
                  ),
                );
              }
            },

          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Setări'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserSettingsScreen(
                    userId: FirebaseAuth.instance.currentUser!.uid,
                  ),
                ),
              );


            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Jurnalul sistemului'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SystemLogScreen(systemLog: _systemLog),
                ),
              );
            },
          ),

          const Divider(),

          // Opțiune Delogare
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Delogare',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              Navigator.pop(context); // inchide drawer-ul
              await FirebaseAuth.instance.signOut();

              // Merge la LoginForm (șterge tot stack-ul anterior)
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginForm()),
                    (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}