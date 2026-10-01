import 'package:flutter/material.dart';
import 'package:kar/screens/create_account.dart';
import 'package:kar/services/auth_service.dart';
import '../screens/home_screen.dart';

class Authentification extends StatelessWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  Authentification({super.key, required this.toggleTheme, required this.isDarkMode});

  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Connexion"),
        ),
        body: Center(
          child: Column(
            children: [
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Mot de passe",
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  var hashedPassword = passwordController.text;
                  final utilisateur = await AuthService.login(
                    password: hashedPassword,
                  );

                  if (utilisateur != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomeScreen(
                          toggleTheme: toggleTheme,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Échec de la connexion")),
                    );
                  }
                },
                child: Text("Se connecter"),
              ),
              SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateAccount(
                        toggleTheme: toggleTheme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  );
                },
                child: const Text("Créer un compte"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}