import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_form.dart';
import 'main.dart';

class ProfileScreen extends StatefulWidget {
  final String username;
  final String role; // "proprietar" sau "locatar"
  final String homeCode;
  final List<String> locatari;

  const ProfileScreen({
    super.key,
    required this.username,
    required this.role,
    required this.homeCode,
    this.locatari = const [],
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String generatedCode;
  late List<String> _activeLocatari;
  String _proprietar = '';

  @override
  void initState() {
    super.initState();
    generatedCode = widget.homeCode;
    _activeLocatari = List.from(widget.locatari);

    if (widget.role == 'locatar') {
      _loadOwnerAndLocatari();
    }
  }

  Future<void> _loadOwnerAndLocatari() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('utilizatori')
        .where('codCasa', isEqualTo: widget.homeCode)
        .get();

    List<String> locatari = [];
    String proprietar = '';

    for (var doc in snapshot.docs) {
      final data = doc.data();

      if (data['role'] == 'proprietar') {
        proprietar = data['username'];
      } else if (data['role'] == 'locatar') {
        locatari.add(data['username']);
      }
    }

    setState(() {
      _activeLocatari = locatari;
      _proprietar = proprietar;
    });
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _showChangeHouseDialog(String uid) async {
    final TextEditingController _codController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Schimbă codul casei',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _codController,
                            decoration: InputDecoration(
                              labelText: 'Introdu noul cod',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              errorText: errorText,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Anulează',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () async {
                                  final cod = _codController.text.trim().toUpperCase();

                                  if (cod.isEmpty) {
                                    setState(() => errorText = 'Introdu un cod!');
                                    return;
                                  }

                                  final result = await FirebaseFirestore.instance
                                      .collection('utilizatori')
                                      .where('codCasa', isEqualTo: cod)
                                      .where('role', isEqualTo: 'proprietar')
                                      .get();

                                  if (result.docs.isEmpty) {
                                    setState(() => errorText = 'Cod invalid!');
                                  } else {
                                    await FirebaseFirestore.instance
                                        .collection('utilizatori')
                                        .doc(uid)
                                        .update({'codCasa': cod});

                                    Navigator.pop(context);

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Codul casei a fost schimbat. Vei fi delogat.',
                                          ),
                                        ),
                                      );
                                    }

                                    await FirebaseAuth.instance.signOut();

                                    if (mounted) {
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(builder: (_) => const LoginForm()),
                                            (route) => false,
                                      );
                                    }
                                  }
                                },
                                child: const Text(
                                  'Confirmă',
                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteLocatariDialog() async {
    final Map<String, bool> selected = {
      for (var name in _activeLocatari) name: false,
    };

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, localSetState) {
            return AlertDialog(
              title: const Text("Selectează locatarii de șters"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: selected.keys.map((locatar) {
                    return CheckboxListTile(
                      title: Text(locatar),
                      value: selected[locatar],
                      onChanged: (bool? value) {
                        localSetState(() {
                          selected[locatar] = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      secondary: selected[locatar]!
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.radio_button_unchecked),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Anulează"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Șterge"),
                  onPressed: () async {
                    final toDelete = selected.entries
                        .where((entry) => entry.value)
                        .map((e) => e.key)
                        .toList();

                    if (toDelete.isEmpty) {
                      Navigator.pop(context);
                      return;
                    }

                    final snapshot = await FirebaseFirestore.instance
                        .collection('utilizatori')
                        .where('codCasa', isEqualTo: widget.homeCode)
                        .where('role', isEqualTo: 'locatar')
                        .get();

                    for (var doc in snapshot.docs) {
                      final data = doc.data();
                      if (toDelete.contains(data['username'])) {
                        await FirebaseFirestore.instance
                            .collection('utilizatori')
                            .doc(doc.id)
                            .update({'codCasa': ""});
                      }
                    }

                    setState(() {
                      _activeLocatari.removeWhere((name) => toDelete.contains(name));
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Locatarii au fost deconectați de la casă.")),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Profil utilizator", style: TextStyle(fontSize: 20)),
        backgroundColor: const Color(0xFFa1c4fd),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.person, size: 30, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.username, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      "Rol: ${widget.role == 'proprietar' ? 'Proprietar' : 'Locatar'}",
                      style: TextStyle(
                        fontSize: 16,
                        color: widget.role == 'proprietar' ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Codul casei tale",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.indigo),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(generatedCode, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.role == 'proprietar')
                    GestureDetector(
                      onTap: () async {
                        final nouCod = _generateRandomCode();
                        final uid = FirebaseAuth.instance.currentUser!.uid;
                        final oldCode = generatedCode;

                        final oldRef = rtdb.child('case/$oldCode');
                        final newRef = rtdb.child('case/$nouCod');

                        try {
                          final oldSnapshot = await oldRef.get();
                          if (!oldSnapshot.exists) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Codul vechi nu există în Realtime Database.")),
                            );
                            return;
                          }

                          final data = oldSnapshot.value;
                          await newRef.set(data);
                          await oldRef.remove();

                          await FirebaseFirestore.instance
                              .collection('utilizatori')
                              .doc(uid)
                              .update({'codCasa': nouCod});

                          final locatariSnapshot = await FirebaseFirestore.instance
                              .collection('utilizatori')
                              .where('codCasa', isEqualTo: oldCode)
                              .where('role', isEqualTo: 'locatar')
                              .get();

                          for (var doc in locatariSnapshot.docs) {
                            await doc.reference.update({'codCasa': ""});
                          }

                          setState(() {
                            generatedCode = nouCod;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Codul casei a fost generat și salvat.")),
                          );
                        } catch (e) {
                          print("Eroare la generare cod: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Eroare: $e")),
                          );
                        }
                      },

                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              offset: const Offset(0, 4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.refresh, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Generează",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Center(
                      child: InkWell(
                        onTap: () => _showChangeHouseDialog(FirebaseAuth.instance.currentUser!.uid),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal:18, vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xC3681CFF), Color(0xFFff7eb3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(width: 10),
                              Text(
                                "Schimbă codul casei",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                ],
              ),
              const SizedBox(height: 12),
              if (widget.role == 'proprietar') ...[
                const Text(
                  "Locatari conectați",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                //buton Sterge locatari
                TextButton.icon(
                  onPressed: () => _showDeleteLocatariDialog(),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    "Șterge locatari",
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),

                const SizedBox(height: 6),
                _activeLocatari.isEmpty
                    ? const Text(
                  "Niciun locatar conectat încă.",
                  style: TextStyle(fontSize: 16),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activeLocatari.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.person_outline, size: 22),
                      title: Text(
                        _activeLocatari[index],
                        style: const TextStyle(fontSize: 16),
                      ),
                      subtitle: const Text(
                        "Acces: activ",
                        style: TextStyle(fontSize: 14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    );
                  },
                ),
              ] else ...[
                Text(
                  "Proprietar: $_proprietar",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Alți locatari conectați în această casă:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 6),
                _activeLocatari.isEmpty
                    ? const Text(
                  "Niciun alt locatar.",
                  style: TextStyle(fontSize: 16),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activeLocatari.where((name) => name != widget.username).length,
                  itemBuilder: (context, index) {
                    final filteredLocatari =
                    _activeLocatari.where((name) => name != widget.username).toList();
                    return ListTile(
                      leading: const Icon(Icons.person_outline, size: 22),
                      title: Text(
                        filteredLocatari[index],
                        style: const TextStyle(fontSize: 16),
                      ),
                      subtitle: const Text(
                        "Locatar în casă",
                        style: TextStyle(fontSize: 14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}