import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'components/error_alert.dart';
import "forgot_pasword_page.dart";
import "signup_form.dart";
import 'components/gradient_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';

class LoginForm extends StatefulWidget {
  final void Function(bool)? onToggleTheme;
  final bool isDarkMode;

  const LoginForm({
    super.key,
    this.onToggleTheme,
    this.isDarkMode = false,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _errorMessage;
  bool _isFormValid = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  void _validateForm() {
    final isValid = _emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;

    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _navigateToProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('utilizatori')
        .doc(user.uid)
        .get();

    var data = doc.data();

    if (data != null) {
      final String role = data['role'] ?? '';
      String homeCode = data['codCasa'] ?? '';

      if (role == 'locatar' && (homeCode.isEmpty || homeCode == '')) {
        await _showCodCasaDialog(user.uid);

        final updatedDoc = await FirebaseFirestore.instance
            .collection('utilizatori')
            .doc(user.uid)
            .get();

        data = updatedDoc.data();
        homeCode = data?['codCasa'] ?? '';
      }
      final String username = data?['username'] ?? '';
      List<String> locatari = [];

      if (role == 'proprietar') {
        final snapshot = await FirebaseFirestore.instance
            .collection('utilizatori')
            .where('codCasa', isEqualTo: homeCode)
            .where('role', isEqualTo: 'locatar')
            .get();

        locatari = snapshot.docs.map((e) => e['username'] as String).toList();
      }

      Navigator.of(context).pushReplacement(
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
  }

  Future<void> _showCodCasaDialog(String uid) async {
    final TextEditingController _codController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text("Conectează-te la o casă"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Pentru a continua, introdu codul unei case:"),
                const SizedBox(height: 12),
                TextField(
                  controller: _codController,
                  decoration: InputDecoration(
                    labelText: "Codul casei",
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  final cod = _codController.text.trim();

                  final result = await FirebaseFirestore.instance
                      .collection('utilizatori')
                      .where('codCasa', isEqualTo: cod)
                      .where('role', isEqualTo: 'proprietar')
                      .get();

                  if (result.docs.isEmpty) {
                    setState(() => errorText = "Cod invalid!");
                  } else {
                    await FirebaseFirestore.instance
                        .collection('utilizatori')
                        .doc(uid)
                        .update({'codCasa': cod});

                    Navigator.pop(context);

                    // După ce codul e valid, mergi la home screen
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  }
                },
                child: const Text("Confirmă"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Completează email-ul și parola!";
      });
      return;
    }

    try {
      UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) return;

      // Verifica dacă emailul este confirmat
      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut(); // delogheaza
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Email neverificat'),
            content: const Text('Te rugăm să îți verifici adresa de email înainte de a te conecta.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }


      final doc = await FirebaseFirestore.instance
          .collection('utilizatori')
          .doc(user.uid)
          .get();

      final data = doc.data();
      final String role = data?['role'] ?? '';
      final String codCasa = data?['codCasa'] ?? '';

      if (role == 'locatar' && codCasa.isEmpty) {
        // cere codul casei intr-un dialog
        await _showCodCasaDialog(user.uid);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Eroare la autentificare.";
      });
    }
  }

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
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 500),
              child: IntrinsicHeight(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.fromLTRB(40, 50, 40, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        offset: const Offset(0, 106),
                        blurRadius: 42,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, 59),
                        blurRadius: 36,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.09),
                        offset: const Offset(0, 26),
                        blurRadius: 26,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(0, 7),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      SvgPicture.asset(
                        'assets/icons/house_check_fill.svg',
                        height: 50,
                        color: const Color(0xFF212121),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Bine ai revenit",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Te rugăm să te autentifici pentru a continua",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF8B8E98)),
                      ),
                      const SizedBox(height: 20),

                      // Email
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Email", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B8E98))),
                          const SizedBox(height: 5),
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.only(left: 40),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7),
                                borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                              ),
                              hintText: "Email",
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Parola
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Parolă",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B8E98),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.only(left: 40),
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
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),

                      // "Ai uitat parola?"
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                            );
                          },
                          child: const Text(
                            "Ai uitat parola?",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF000000),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 1),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ErrorAlert(
                            message: _errorMessage!,
                            onClose: () => setState(() => _errorMessage = null),
                          ),
                        ),

                      const SizedBox(height: 10),

                      GradientButton(
                        text: "Conectează-te",
                        onPressed: _handleLogin,
                        enabled: _isFormValid,
                      ),

                      const SizedBox(height: 10),

                      const SizedBox(height: 20),

                      // Link catre Sign Up
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignupForm()),
                          );
                        },
                        child: const Text("Nu ai cont? Creează unul"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}