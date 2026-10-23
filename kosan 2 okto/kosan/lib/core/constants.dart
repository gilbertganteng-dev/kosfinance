// ============================================================
// COLORS & KONSTANTA
// ============================================================

import 'package:flutter/material.dart';

// Warna utama aplikasi (hijau) dan turunannya
const Color primaryGreen = Color(0xFF2E7D32); // warna AppBar, tombol utama
const Color lightGreen = Color(0xFFE8F5E9); // hijau muda untuk latar ikon/kartu
const Color backgroundColor = Color(0xFFF5F7F5); // warna latar halaman

// 3 tahap status pembayaran (+ kadaluarsa) sesuai arahan dosen
const String stBelum = 'Belum Dibayar'; // tagihan baru, belum ada pembayaran
const String stProses = 'Menunggu Konfirmasi'; // penghuni sudah kirim bukti, admin belum cek
const String stLunas = 'Sudah Dibayar'; // admin sudah konfirmasi
const String stKadaluarsa = 'Kadaluarsa';

// Info pembayaran (ganti sesuai data pemilik kos)
const String ownerPhone = '081234567800';
const String bankInfo = 'BCA 1234567890\na.n. Pemilik Kos';

// Listrik & air: tarif tetap per bulan, sudah digabung ke tagihan sewa.
// Dibuat variabel (bukan const) supaya admin bisa mengubahnya dari menu Kamar & Harga.
double utilityFee = 150000;

// Lokasi kos: STMIK LIKMI Bandung.
// Koordinat diambil dari titik (pin) pada link Google Maps: -6.8954667, 107.6131999
const String kosLocationName = 'STMIK LIKMI Bandung';
const String kosMapUrl =
    'https://www.google.com/maps/search/?api=1&query=-6.8954667,107.6131999';

// Kategori PEMASUKAN.
// 'Ganti Rugi Kerusakan' = uang ganti dari penghuni jika kerusakan akibat kesalahannya sendiri.
const List<String> incomeCategories = ['Iuran', 'Ganti Rugi Kerusakan', 'Lainnya'];

// Kategori PENGELUARAN = biaya yang ditanggung pemilik kos.
// Listrik & air dibayar pemilik (di sisi penghuni sudah include di tagihan kamar).
// Kebersihan TIDAK ada karena itu tanggung jawab masing-masing penghuni.
const List<String> expenseCategories = [
  'Listrik',
  'Air',
  'WiFi / Internet',
  'Gaji Penjaga',
  'Lampu & Penerangan',
  'Perbaikan Fasilitas',
  'Lainnya',
];

// Pengeluaran yang terjadi tiap bulan (dipakai untuk checklist "Pengeluaran Rutin")
const List<String> routineExpenseCategories = ['Listrik', 'Air', 'WiFi / Internet', 'Gaji Penjaga'];

// Kategori laporan kerusakan (permintaan dosen: pilih list, selain itu "Lainnya")
const List<String> complaintCategories = ['Air', 'Listrik', 'AC', 'Lampu', 'Lainnya'];
