import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserSettingsScreen extends StatefulWidget {
  final String userId;

  const UserSettingsScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  String? _currentUsername;
  bool _isLoading = true;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('utilizatori')
          .doc(widget.userId)
          .get();
      final fetchedUsername = userDoc['username'];
      setState(() {
        _currentUsername = fetchedUsername;
        _usernameController.text = fetchedUsername;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eroare la încărcarea datelor.')),
      );
    }
  }

  Future<void> _changeUsername() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername.isNotEmpty && newUsername != _currentUsername) {
      try {
        await FirebaseFirestore.instance
            .collection('utilizatori')
            .doc(widget.userId)
            .update({'username': newUsername});

        setState(() {
          _currentUsername = newUsername;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numele de utilizator a fost actualizat!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eroare la actualizarea numelui.')),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.isNotEmpty) {
      try {
        await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parola a fost schimbată!')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eroare la schimbarea parolei.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setări utilizator'),
        backgroundColor: const Color(0xFFa1c4fd),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bună, $_currentUsername',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text(
              'Nume utilizator actual: $_currentUsername',
              style: const TextStyle(fontSize: 18),
            ),
            const Divider(height: 32),
            const Text(
              'Schimbă numele de utilizator:',
              style: TextStyle(fontSize: 17,fontWeight: FontWeight.bold),
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
              style: TextStyle(fontSize: 17,fontWeight: FontWeight.bold),
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
