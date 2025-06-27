import 'package:flutter/material.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({Key? key}) : super(key: key);

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  String _currentUsername= "";
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _changeUsername() {
    if (_usernameController.text.trim().isNotEmpty) {
      setState(() {
        _currentUsername = _usernameController.text.trim();
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numele de utilizator a fost actualizat!')),
      );
    }
  }

  void _changePassword() {
    if (_passwordController.text.trim().isNotEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parola a fost schimbată!')),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setări utilizator'),
        backgroundColor: const Color(0xFFa1c4fd),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bună, $_currentUsername!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),
            Text(
              'Nume utilizator actual: $_currentUsername',
              style: const TextStyle(fontSize: 16),
            ),
            const Divider(height: 32),
            const Text(
              'Schimbă numele de utilizator:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                hintText: 'Nume nou...',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _changeUsername,
              icon: const Icon(Icons.person),
              label: const Text('Schimbă numele'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFa1c4fd),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Schimbă parola:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Parolă nouă...',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock),
              label: const Text('Schimbă parola'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFa1c4fd),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),

    );
  }
}