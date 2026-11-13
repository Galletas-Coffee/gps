import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

// Cambia esta URL por la IP de tu servidor FastAPI
const String baseUrl = "http://127.0.0.1:8000";

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pase de Lista GPS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
    );
  }
}

// --- PANTALLA DE LOGIN Y REGISTRO ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _authenticate(String endpoint) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": _userController.text.trim(),
          "password": _passController.text.trim(),
        }),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceScreen(userId: data['user_id']),
          ),
        );
      } else {
        _showMessage(data['detail'] ?? 'Error de autenticación');
      }
    } catch (e) {
      _showMessage('Error de conexión con el servidor');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso al Sistema')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: 'Usuario'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _authenticate('login'),
                    child: const Text('Iniciar Sesión'),
                  ),
                  OutlinedButton(
                    onPressed: () => _authenticate('register'),
                    child: const Text('Registrarse'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// --- PANTALLA PRINCIPAL DE ASISTENCIA ---
class AttendanceScreen extends StatefulWidget {
  final int userId;
  const AttendanceScreen({super.key, required this.userId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _address = "";
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchAttendanceHistory();
  }

  Future<void> _fetchAttendanceHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/${widget.userId}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _history = data;
        });
      }
    } catch (e) {
      _showError('No se pudo cargar el historial');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Los servicios de ubicación están desactivados.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permisos de ubicación denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permisos denegados permanentemente.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _registerAttendance() async {
    setState(() => _isLoading = true);
    try {
      Position position = await _determinePosition();

      final response = await http.post(
        Uri.parse('$baseUrl/attendance/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": widget.userId,
          "latitude": position.latitude,
          "longitude": position.longitude,
        }),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        setState(() {
          _address = data['address'];
        });
        await _fetchAttendanceHistory();
      } else {
        _showError(data['detail'] ?? 'No se pudo registrar la asistencia');
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Asistencia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAttendanceHistory,
            tooltip: 'Actualizar historial',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _registerAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23478A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                _isLoading ? 'Obteniendo ubicación...' : 'Registrar asistencia',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            if (_address.isNotEmpty)
              Card(
                color: Colors.blue.shade50,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    "📍 Último registro:\n$_address",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Historial de Asistencias',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _history.isEmpty
                  ? const Center(
                      child: Text('Aún no tienes asistencias registradas.'),
                    )
                  : ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              color: Color(0xFF23478A),
                            ),
                            title: Text(
                              item['address'] ?? 'Dirección no disponible',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item['created_at'] != null &&
                                      item['created_at'] != 'None'
                                  ? 'Fecha: ${item['created_at']}'
                                  : 'Lat: ${item['latitude']}, Lng: ${item['longitude']}',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
