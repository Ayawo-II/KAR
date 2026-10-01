import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kar/screens/authentification.dart';
import 'package:kar/screens/home_screen.dart';
import '../services/auth_service.dart';
import '../data/database_helper.dart';
import '../models/utilisateur.dart';
import '../main.dart';

class CreateAccount extends StatefulWidget {

  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const CreateAccount({super.key, required this.toggleTheme, required this.isDarkMode});
  @override
  State<CreateAccount> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<CreateAccount> {

  DateTime? selectedDate;
  String? selectedSexe;

  final TextEditingController nomController = TextEditingController();
  final TextEditingController prenomsController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  Future<void> creerCompte() async {

    if (nomController.text.isEmpty ||
        prenomsController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Veuillez remplir tous les champs.")),
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Les mots de passe ne correspondent pas.")),
      );
      return;
    }

    // Créer une instance de Utilisateur
    Utilisateur user = Utilisateur(
      nom: nomController.text,
      prenoms: prenomsController.text,
      password: AuthService.hashPassword(passwordController.text),
    );

    // Appeler la méthode pour ajouter l'utilisateur
    int result = await DatabaseHelper.instance.ajouterUtilisateur(user);

    if (result > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Utilisateur enregistré avec succès !")),
      );
      
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Authentification(toggleTheme: widget.toggleTheme, isDarkMode: widget.isDarkMode))
      );

      nomController.clear();
      prenomsController.clear();
      passwordController.clear();
      confirmPasswordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'enregistrement de l'utilisateur.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(child: Scaffold(
      appBar: AppBar(
        title: Text("Créez un compte"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Form(
          child: Column(
            children: [
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Nom",
                ),
              ),

              SizedBox(height: screenHeight*0.01),

              TextField(
                  controller: prenomsController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Prénoms",
                ),
              ),

              SizedBox(height: screenHeight*0.01),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Mot de passe",
                ),
              ),

              SizedBox(height: screenHeight*0.01),

              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Confirmation de mot de passe",
                ),
              ),

              SizedBox(height: screenHeight*0.01),

              ElevatedButton(
                  onPressed: (){
                    creerCompte();
                  },
                  child: Text("Enregistrer")
              )

            ],
          ),
        ),
      ),
    ));
  }
}
