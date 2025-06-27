import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReconnectHouseScreen extends StatefulWidget {
  const ReconnectHouseScreen({super.key});

  @override
  State<ReconnectHouseScreen> createState() => _ReconnectHouseScreenState();
}

class _ReconnectHouseScreenState extends State<ReconnectHouseScreen> {
  final TextEditingController _codController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitCode() async {
    FocusScope.of(context).unfocus(); // inchide tastatura
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final cod = _codController.text.trim();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // Verificare daca exista vreo casa cu acel cod (de proprietar)
      final result = await FirebaseFirestore.instance
          .collection('utilizatori')
          .where('codCasa', isEqualTo: cod)
          .where('role', isEqualTo: 'proprietar')
          .get();

      if (result.docs.isEmpty) {
        setState(() {
          _errorMessage = "Codul introdus nu aparține niciunei case.";
          _isLoading = false;
        });
        return;
      }

      // Actualizare codul casei la locatarul curent
      await FirebaseFirestore.instance.collection('utilizatori').doc(uid).update({
        'codCasa': cod,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Te-ai conectat cu succes la casa!")),
      );

      Navigator.of(context).pop(); // Înapoi în aplicație
    } catch (e) {
      setState(() {
        _errorMessage = "A apărut o eroare. Încearcă din nou.";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reconectare la o casă")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ai fost eliminat din casa anterioară.",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              "Pentru a continua, introdu codul unei case pentru a te reconecta.",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codController,
              decoration: const InputDecoration(
                labelText: "Codul casei",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitCode,
                icon: const Icon(Icons.login),
                label: _isLoading
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text("Conectează-mă"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
