// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_database/firebase_database.dart';
//
// class SensorsScreen extends StatefulWidget {
//   const SensorsScreen({super.key});
//
//   @override
//   State<SensorsScreen> createState() => _SensorsScreenState();
// }
//
// class _SensorsScreenState extends State<SensorsScreen> {
//   late FirebaseDatabase _rtdb;
//   late DatabaseReference _mesajRef;
//
//   String _mesaj = "Aștept date...";
//   final TextEditingController _controller = TextEditingController();
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeFirebaseDatabase();
//   }
//
//   Future<void> _initializeFirebaseDatabase() async {
//     try {
//       final firebaseApp = Firebase.app();
//       _rtdb = FirebaseDatabase.instanceFor(
//         app: firebaseApp,
//         databaseURL: 'https://aplicatiemobile-4bbf7-default-rtdb.europe-west1.firebasedatabase.app/',
//       );
//       _mesajRef = _rtdb.ref('mesaje/text');
//       _citesteMesaj();
//     } catch (e) {
//       setState(() {
//         _mesaj = "Eroare la conectare: $e";
//       });
//     }
//   }
//
//   Future<void> _citesteMesaj() async {
//     try {
//       final snapshot = await _mesajRef.get();
//       if (snapshot.exists) {
//         setState(() {
//           _mesaj = snapshot.value.toString();
//         });
//       } else {
//         setState(() {
//           _mesaj = "Nu există date.";
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _mesaj = "Eroare la citire: $e";
//       });
//     }
//   }
//
//   Future<void> _scrieMesaj() async {
//     final nouText = _controller.text.trim();
//     if (nouText.isEmpty) return;
//
//     try {
//       await _mesajRef.set(nouText);
//       setState(() {
//         _mesaj = nouText;
//         _controller.clear();
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Eroare la scriere: $e")),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Senzori - Firebase Demo"),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text(
//               "Mesaj curent:",
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               _mesaj,
//               style: const TextStyle(fontSize: 18),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 20),
//             TextField(
//               controller: _controller,
//               decoration: const InputDecoration(
//                 labelText: "Scrie un mesaj nou",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),
//             ElevatedButton(
//               onPressed: _scrieMesaj,
//               child: const Text("Trimite mesaj"),
//             ),
//             const SizedBox(height: 12),
//             TextButton(
//               onPressed: _citesteMesaj,
//               child: const Text("Reîncarcă mesajul"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
