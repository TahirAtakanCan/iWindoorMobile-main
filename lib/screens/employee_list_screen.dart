import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<UserModel>> _employeesFuture;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _refreshList();
  }

  Future<void> _loadRole() async {
    final role = await AuthService().getRole();
    setState(() {
      _currentUserRole = role;
    });
  }

  void _refreshList() {
    setState(() {
      _employeesFuture = _apiService.getEmployees();
    });
  }

  // Yeni Çalışan Ekleme Dialogu
  void _showAddEmployeeDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Çalışan Ekle"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Ad Soyad")),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: "E-Posta")),
              TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Şifre"), obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.isEmpty) return;
              
              Navigator.pop(context); // Dialogu kapat
              
              bool success = await _apiService.createEmployee(
                nameController.text, 
                emailController.text, 
                passwordController.text
              );

              if (success) {
                _refreshList();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Çalışan eklendi.")));
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu."), backgroundColor: Colors.red));
              }
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Çalışan Yönetimi")),
      floatingActionButton: _currentUserRole == 'COMPANY_ADMIN'
          ? FloatingActionButton(
              onPressed: _showAddEmployeeDialog,
              child: const Icon(Icons.person_add),
            )
          : null,
      body: FutureBuilder<List<UserModel>>(
        future: _employeesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Henüz çalışan eklenmemiş."));
          }

          final employees = snapshot.data!;

          return ListView.builder(
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final emp = employees[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(child: Text(emp.fullName[0].toUpperCase())),
                  title: Text(emp.fullName),
                  subtitle: Text(emp.email),
                  trailing: Chip(
                    label: Text(emp.role == 'COMPANY_ADMIN' ? 'Yönetici' : 'Çalışan'),
                    backgroundColor: emp.role == 'COMPANY_ADMIN' ? Colors.orange.shade100 : Colors.blue.shade100,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}