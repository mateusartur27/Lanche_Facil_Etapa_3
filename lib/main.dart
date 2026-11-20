import 'package:flutter/material.dart';

import 'config/theme.dart';
import 'staff/staff_app.dart';

// Prepara os plugins do Flutter e abre a área de gestão, que decide se deve mostrar o login.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'Lanche Fácil — Gestão do Cardápio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const StaffApp(),
    ),
  );
}
