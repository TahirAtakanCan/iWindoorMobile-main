import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen alanları doldurun.")));
      setState(() => _isLoading = false);
      return;
    }

    final success = await _authService.login(email, password);

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      // Ana Sayfaya Yönlendir
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giriş Başarısız! Bilgileri kontrol edin."), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo veya İkon
              const Icon(Icons.window, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text("iWindoor", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const Text("Pencere Tasarım Sistemi", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // E-posta Alanı
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "E-Posta",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Şifre Alanı
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Şifre",
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // Giriş Butonu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("GİRİŞ YAP", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 20),
              // Kayıt Ol Linki (İleride RegisterScreen eklenebilir)
              TextButton(
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kayıt olma özelliği yakında eklenecek.")));
                }, 
                child: const Text("Hesabın yok mu? Kayıt Ol")
              )
            ],
          ),
        ),
      ),
    );
  }
}