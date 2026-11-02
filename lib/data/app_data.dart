// ============================================================
// DATA PRESENTATION (diisi dari REST API Laravel saat aplikasi dibuka)
//
// List ini hanya cache tampilan dalam memori. Backend Laravel adalah sumber
// kebenaran; semua perubahan bisnis harus dikirim ke endpoint API terlebih dahulu.
// ============================================================

import 'package:flutter/material.dart';

import '../core/helpers.dart';
import '../models/models.dart';

List<AdminNotificationData> adminNotifications = [];
List<ResidentNotificationData> residentNotifications = [];
List<ResidentNotificationData> notificationsFor(UserAccount u) {
  final name = u.name.toLowerCase();
  return residentNotifications
      .where((n) => n.residentName.toLowerCase() == name)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

// Notifier agar halaman yang masih terbuka ikut memperbarui data bersama.
// Setiap kali data berubah, angka ini +1 dan semua halaman yang "mendengarkan" ikut refresh.
final ValueNotifier<int> appDataRevision = ValueNotifier<int>(0);

void notifyDataChanged() {
  appDataRevision.value++;
}

// Laporan kerusakan (tabel complaints)
List<ComplaintData> complaints = [];

// Pengumuman & peraturan (tabel announcements)
List<AnnouncementData> announcements = [];

// Transaksi keuangan (tabel transactions)
List<TransactionData> transactions = [];

// Tagihan / iuran (tabel iuran)
List<IuranData> iuranList = [];

// Akun login (tabel accounts). Password tidak pernah dimuat ke aplikasi; login dicek oleh server.
List<UserAccount> accounts = [];

// Tipe kamar (tabel room_types; bisa diedit admin lewat menu Kamar & Harga)
final List<RoomType> roomTypes = [];

// Daftar kamar (tabel rooms)
List<Room> rooms = [];

// ---------- Fungsi bantu yang membaca data global ----------

// Rincian pengeluaran per kategori pada satu bulan, diurutkan dari yang terbesar.
// Dipakai di dashboard admin & halaman laporan supaya admin tahu uang keluar untuk apa saja.
List<MapEntry<String, double>> expenseBreakdown(DateTime month) {
  final map = <String, double>{};
  for (final t in transactions) {
    if (t.type == 'Pengeluaran' && transactionInMonth(t, month)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
  }
  return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

// Jumlah kamar kosong (semua tipe, atau tipe tertentu)
int vacantCount([int? typeIndex]) => rooms
    .where((r) => r.status == 'Kosong' && (typeIndex == null || r.typeIndex == typeIndex))
    .length;

// Daftar tagihan milik satu penghuni
List<IuranData> iuranFor(UserAccount u) => iuranList.where((bill) {
      if (u.id != null && bill.userId != null) return bill.userId == u.id;
      // Legacy-only fallback for offline/mock data without server IDs.
      return u.id == null && bill.residentName.toLowerCase() == u.name.toLowerCase();
    }).toList();

// Kamar dihubungkan menggunakan foreign key. Nama hanya fallback untuk data demo lama.
Room? roomOf(UserAccount u) {
  for (final room in rooms) {
    if (u.id != null) {
      if (room.residentId == u.id) return room;
      continue;
    }
    if (room.residentName?.toLowerCase() == u.name.toLowerCase()) return room;
  }
  return null;
}

