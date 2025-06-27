import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'components/gradient_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'login_form.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();
  final codCasaController = TextEditingController();

  String _selectedRole = 'locatar';
  bool _isLoading = false;
  bool _isPasswordVisible = false;


  String _generateRandomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = credential.user!.uid;
      final username = usernameController.text.trim();
      final email = emailController.text.trim();

      String codCasa;
      if (_selectedRole == 'proprietar') {
        codCasa = _generateRandomCode();
      } else {
        codCasa = codCasaController.text.trim();
      }
      // Trimite email de verificare
      await credential.user!.sendEmailVerification();

      await FirebaseFirestore.instance.collection('utilizatori').doc(uid).set({
        'username': username,
        'email': email,
        'role': _selectedRole,
        'codCasa': codCasa,
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verificare email'),
          content: const Text(
            'Ți-am trimis un email de verificare.\nTe rugăm să îți verifici adresa de email înainte să te conectezi.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginForm()),
                      (route) => false,
                );
              },

              child: const Text('OK'),
            ),
          ],
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFa1c4fd),
              Color(0xFFc2e9fb),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.fromLTRB(40, 50, 40, 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/house_add_fill.svg',
                      height: 50,
                      color: const Color(0xFF212121),
                    ),
                    const SizedBox(height: 10),

                    const Text(
                      "Creează un cont",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Nume utilizator
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        "Nume utilizator",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B8E98)),
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.only(left: 40),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
                        hintText: "Nume",
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Introdu un nume' : null,
                    ),
                    const SizedBox(height: 10),

                    // Email
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const Text("Email", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B8E98))),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.only(left: 40),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
                        hintText: "Email",
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => val != null && val.contains('@') ? null : 'Email invalid',
                    ),
                    const SizedBox(height: 10),

                    // Parola
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        "Parolă",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B8E98),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.only(left: 40, right: 40),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7),
                          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                        ),
                        hintText: "Parolă",
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Introdu o parolă';

                        if (val.length < 8) return 'Minim 8 caractere';
                        if (!RegExp(r'[a-z]').hasMatch(val)) return 'Include cel puțin o literă mică';
                        if (!RegExp(r'[A-Z]').hasMatch(val)) return 'Include cel puțin o literă mare';
                        if (!RegExp(r'[0-9]').hasMatch(val)) return 'Include cel puțin o cifră';
                        if (!RegExp(r'[!@#\$&*~%^()_\-+=<>?/]').hasMatch(val)) return 'Include un caracter special';

                        return null;
                      },
                    ),


                    // Rol
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(labelText: 'Rol'),
                      items: const [
                        DropdownMenuItem(value: 'locatar', child: Text('Locatar')),
                        DropdownMenuItem(value: 'proprietar', child: Text('Proprietar')),
                      ],
                      onChanged: (val) => setState(() => _selectedRole = val!),
                    ),
                    const SizedBox(height: 10),

                    // Cod casa doar daca e locatar
                    if (_selectedRole == 'locatar')
                      TextFormField(
                        controller: codCasaController,
                        decoration: const InputDecoration(labelText: 'Codul casei'),
                        validator: (val) => val == null || val.isEmpty ? 'Introdu codul casei' : null,
                      ),

                    const SizedBox(height: 20),

                    // Buton creare cont
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: GradientButton(
                        text: _isLoading ? 'Se creează...' : 'Creează cont',
                        enabled: !_isLoading,
                        onPressed: _signUp,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Inapoi la autentificare
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "⟵ Înapoi la autentificare",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000205),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}