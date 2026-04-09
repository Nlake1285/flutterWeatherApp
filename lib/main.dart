import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        }

        return const SignInPage();
      },
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  String? _errorMessage;
  bool _loading = false;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Email and password are required.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegistering) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Authentication failed. Please try again.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In / Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isRegistering ? 'Register' : 'Sign in'),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() {
                        _isRegistering = !_isRegistering;
                        _errorMessage = null;
                      });
                    },
              child: Text(_isRegistering
                  ? 'Already have an account? Sign in'
                  : 'Create a new account'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LocationEntry? _selectedLocation;
  Future<WeatherData>? _weatherFuture;
  String? _errorText;
  bool _useMetric = true;
  bool _showStats = false;

  late final String _uid;
  late final CollectionReference<Map<String, dynamic>> _locationsRef;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('User must be signed in.');
    }
    _uid = currentUser.uid;
    _locationsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('locations');
  }

  void _selectLocation(LocationEntry location) {
    setState(() {
      _selectedLocation = location;
      _weatherFuture = OpenMeteoApi.fetchWeather(
        location.latitude,
        location.longitude,
        unit: _useMetric ? TemperatureUnit.celsius : TemperatureUnit.fahrenheit,
      );
      _errorText = null;
    });
  }

  void _setMeasurementUnit(bool useMetric) {
    setState(() {
      _useMetric = useMetric;
      if (_selectedLocation != null) {
        _weatherFuture = OpenMeteoApi.fetchWeather(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
          unit: _useMetric ? TemperatureUnit.celsius : TemperatureUnit.fahrenheit,
        );
      }
    });
  }

  Future<void> _addLocation() async {
    final nameController = TextEditingController();
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        String? formError;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add Location'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: latitudeController,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: longitudeController,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType: TextInputType.number,
                    ),
                    if (formError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(formError!, style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final latitude = double.tryParse(latitudeController.text.trim());
                    final longitude = double.tryParse(longitudeController.text.trim());

                    if (name.isEmpty || latitude == null || longitude == null) {
                      setStateDialog(() {
                        formError = 'Enter valid name and coordinates.';
                      });
                      return;
                    }

                    _locationsRef.add({
                      'name': name,
                      'latitude': latitude,
                      'longitude': longitude,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteLocation(String id) async {
    await _locationsRef.doc(id).delete();
    if (_selectedLocation?.id == id) {
      setState(() {
        _selectedLocation = null;
        _weatherFuture = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Locations'),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.blue.shade50,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signed in as ${user?.email ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Tap a location to fetch weather, or add a new one.'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Units:'),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Metric'),
                      selected: _useMetric,
                      onSelected: (selected) {
                        if (selected) _setMeasurementUnit(true);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Imperial'),
                      selected: !_useMetric,
                      onSelected: (selected) {
                        if (selected) _setMeasurementUnit(false);
                      },
                    ),
                    const SizedBox(width: 16),
                    const Text('Stats:'),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Nerd'),
                      selected: _showStats,
                      onSelected: (selected) {
                        setState(() {
                          _showStats = selected;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_selectedLocation != null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weather for ${_selectedLocation!.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_weatherFuture == null)
                    const Text('Tap a location to fetch weather.')
                  else
                    FutureBuilder<WeatherData>(
                      future: _weatherFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Text('Unable to load weather: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                        }

                        final weather = snapshot.data;
                        if (weather == null) {
                          return const Text('No weather data.');
                        }

                        return WeatherCard(
                          location: _selectedLocation!.name,
                          data: weather,
                          showStats: _showStats,
                        );
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _locationsRef.orderBy('createdAt').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error loading locations: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No saved locations yet. Tap + to add one.'));
                }

                final locations = docs.map((doc) {
                  final data = doc.data();
                  return LocationEntry(
                    id: doc.id,
                    name: data['name'] as String? ?? 'Unknown',
                    latitude: (data['latitude'] as num).toDouble(),
                    longitude: (data['longitude'] as num).toDouble(),
                  );
                }).toList();

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: locations.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final location = locations[index];
                    final selected = location.id == _selectedLocation?.id;
                    return ListTile(
                      tileColor: selected ? Colors.blue.shade50 : null,
                      title: Text(location.name),
                      subtitle: Text('Lat ${location.latitude}, Lon ${location.longitude}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteLocation(location.id),
                      ),
                      onTap: () => _selectLocation(location),
                    );
                  },
                );
              },
            ),
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLocation,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class WeatherCard extends StatelessWidget {
  final String location;
  final WeatherData data;
  final bool showStats;

  const WeatherCard({super.key, required this.location, required this.data, required this.showStats});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(location, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${data.temperature.toStringAsFixed(1)}°${data.unitSymbol}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Text(data.description, style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Text('Code: ${data.weatherCode}'),
                Text('Updated: ${data.time}'),
              ],
            ),
            if (showStats) ...[
              const Divider(height: 24),
              Text('Wind: ${data.windSpeed.toStringAsFixed(1)} ${data.windSpeedUnit} at ${data.windDirection}°'),
              const SizedBox(height: 4),
              Text('Weather code raw: ${data.weatherCode}'),
              const SizedBox(height: 4),
              Text('Data time: ${data.time}'),
            ],
          ],
        ),
      ),
    );
  }
}

class LocationEntry {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  LocationEntry({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class WeatherData {
  final double temperature;
  final int weatherCode;
  final String time;
  final String description;
  final String unitSymbol;
  final double windSpeed;
  final int windDirection;
  final String windSpeedUnit;

  WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.time,
    required this.description,
    required this.unitSymbol,
    required this.windSpeed,
    required this.windDirection,
    required this.windSpeedUnit,
  });

  factory WeatherData.fromJson(
    Map<String, dynamic> json,
    String unitSymbol,
    String windSpeedUnit,
  ) {
    final temperature = (json['temperature'] as num).toDouble();
    final weatherCode = (json['weathercode'] as num).toInt();
    final time = json['time'] as String;
    final windSpeed = (json['windspeed'] as num).toDouble();
    final windDirection = (json['winddirection'] as num).toInt();

    return WeatherData(
      temperature: temperature,
      weatherCode: weatherCode,
      time: time,
      description: OpenMeteoApi.weatherDescription(weatherCode),
      unitSymbol: unitSymbol,
      windSpeed: windSpeed,
      windDirection: windDirection,
      windSpeedUnit: windSpeedUnit,
    );
  }
}

enum TemperatureUnit { celsius, fahrenheit }

class OpenMeteoApi {
  static Future<WeatherData> fetchWeather(
    double latitude,
    double longitude, {
    required TemperatureUnit unit,
  }) async {
    final unitName = unit == TemperatureUnit.celsius ? 'celsius' : 'fahrenheit';
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&temperature_unit=$unitName&timezone=auto',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Open-Meteo request failed: ${response.statusCode}');
    }

    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    final current = jsonBody['current_weather'] as Map<String, dynamic>?;
    if (current == null) {
      throw Exception('Open-Meteo returned no current weather.');
    }

    return WeatherData.fromJson(
      current,
      unit == TemperatureUnit.celsius ? 'C' : 'F',
      unit == TemperatureUnit.celsius ? 'km/h' : 'mph',
    );
  }

  static String weatherDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1 || code == 2 || code == 3) return 'Partly cloudy';
    if (code == 45 || code == 48) return 'Fog';
    if (code == 51 || code == 53 || code == 55) return 'Drizzle';
    if (code == 56 || code == 57) return 'Freezing drizzle';
    if (code == 61 || code == 63 || code == 65) return 'Rain';
    if (code == 66 || code == 67) return 'Freezing rain';
    if (code == 71 || code == 73 || code == 75) return 'Snow';
    if (code == 77) return 'Snow grains';
    if (code == 80 || code == 81 || code == 82) return 'Rain showers';
    if (code == 85 || code == 86) return 'Snow showers';
    if (code == 95 || code == 96 || code == 99) return 'Thunderstorm';
    return 'Unknown weather';
  }
}