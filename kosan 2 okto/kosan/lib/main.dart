// ============================================================
// KosFinance - Aplikasi Pencatat Keuangan & Pengelolaan Kos (Flutter Web)
// Dua peran: Admin (pemilik kos) dan Penghuni (calon penghuni / penghuni).
// Data disimpan di memori (List global) -> hilang saat aplikasi di-refresh.
//
// STRUKTUR FOLDER lib/:
//   core/     -> konstanta (warna, status, kategori) & fungsi bantu
//   models/   -> class data (Transaksi, Iuran, Akun, Kamar, dll.)
//   data/     -> data dummy global + logika tagihan (markPaid, booking, dll.)
//   widgets/  -> widget yang dipakai berulang (kartu, pill, grafik)
//   pages/    -> semua halaman: auth/, admin/, customer/, shared/
// ============================================================

import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'pages/auth/login_page.dart';

// Titik awal aplikasi: menjalankan widget utama KosFinanceApp
void main() {
  runApp(const KosFinanceApp());
}

// ============================================================
// APP (konfigurasi tema & halaman awal)
// ============================================================

class KosFinanceApp extends StatelessWidget {
  const KosFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // sembunyikan pita "debug"
      title: 'KosFinance',
      // Tema global: semua halaman otomatis memakai warna & bentuk ini
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
        ),
      ),
      home: const LoginPage(), // halaman pertama yang tampil
    );
  }
}
