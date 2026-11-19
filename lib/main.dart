import 'package:flutter/material.dart';

import 'config/theme.dart';
import 'staff/staff_app.dart';

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
