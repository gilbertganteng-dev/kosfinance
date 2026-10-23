// ============================================================
// DATA GLOBAL (dummy, disimpan di memori) + fungsi bantu yang membaca data tersebut
// ============================================================

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/helpers.dart';
import '../models/models.dart';

List<AdminNotificationData> adminNotifications = [];
List<ResidentNotificationData> residentNotifications = [];

// Notifier agar halaman yang masih terbuka ikut memperbarui data bersama.
// Setiap kali data berubah, angka ini +1 dan semua halaman yang "mendengarkan" ikut refresh.
final ValueNotifier<int> appDataRevision = ValueNotifier<int>(0);

void notifyDataChanged() {
  appDataRevision.value++;
}

// Laporan kerusakan contoh (bulan ini) agar statistik admin langsung terlihat
List<ComplaintData> complaints = [
  ComplaintData(
    id: 1,
    residentName: 'Andi',
    roomNumber: '201',
    category: 'AC',
    description: 'AC menyala tapi tidak dingin dan suhunya tidak bisa dinaikkan.',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    status: 'Diproses',
  ),
  ComplaintData(
    id: 2,
    residentName: 'Budi',
    roomNumber: '106',
    category: 'Air',
    description: 'Keran kamar mandi bocor terus-menerus.',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  ComplaintData(
    id: 3,
    residentName: 'Gita',
    roomNumber: '107',
    category: 'Listrik',
    description: 'Stop kontak dekat kasur mati.',
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
  ),
  ComplaintData(
    id: 4,
    residentName: 'Hendra',
    roomNumber: '108',
    category: 'AC',
    description: 'AC mengeluarkan bunyi berisik saat dinyalakan.',
    createdAt: DateTime.now().subtract(const Duration(hours: 10)),
    status: 'Selesai',
  ),
  ComplaintData(
    id: 5,
    residentName: 'Indah',
    roomNumber: '206',
    category: 'Lampu',
    description: 'Lampu kamar mati dan berkedip.',
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
  ),
];

// Pengumuman awal
List<AnnouncementData> announcements = [
  AnnouncementData(
    id: 1,
    title: 'Selamat datang di KosFinance',
    body: 'Gunakan aplikasi untuk mengecek tagihan, melaporkan kerusakan, dan membaca informasi kos.',
    createdAt: DateTime(2026, 10, 1),
  ),
  AnnouncementData(
    id: 2,
    title: 'Peraturan kos',
    body: 'Jaga kebersihan kamar masing-masing, matikan listrik saat meninggalkan kamar, jaga ketenangan setelah pukul 22.00, dan laporkan kerusakan melalui aplikasi. Kerusakan akibat kelalaian penghuni menjadi tanggung jawab penghuni.',
    createdAt: DateTime(2026, 10, 1),
  ),
];

// Membuat teks tanggal pada bulan ini (dipakai agar data contoh selalu masuk laporan bulan berjalan)
String _dayThisMonth(int day) => formatDate(DateTime(today.year, today.month, day));

// Transaksi awal (contoh).
// Pengeluaran = biaya yang ditanggung pemilik: listrik, wifi, penjaga, lampu, perbaikan.
List<TransactionData> transactions = [
  TransactionData(id: 1, date: _dayThisMonth(1), description: 'Pembayaran iuran Andi', category: 'Iuran', type: 'Pemasukan', amount: 1250000),
  TransactionData(id: 2, date: _dayThisMonth(3), description: 'Pembayaran iuran Budi', category: 'Iuran', type: 'Pemasukan', amount: 1050000),
  TransactionData(id: 3, date: _dayThisMonth(5), description: 'Tagihan listrik PLN bulan ini', category: 'Listrik', type: 'Pengeluaran', amount: 2000000),
  TransactionData(id: 4, date: _dayThisMonth(6), description: 'Langganan WiFi bulanan', category: 'WiFi / Internet', type: 'Pengeluaran', amount: 350000),
  TransactionData(id: 5, date: _dayThisMonth(7), description: 'Gaji penjaga kos', category: 'Gaji Penjaga', type: 'Pengeluaran', amount: 1500000),
  TransactionData(id: 6, date: _dayThisMonth(8), description: 'Ganti lampu lorong yang redup', category: 'Lampu & Penerangan', type: 'Pengeluaran', amount: 80000),
  TransactionData(id: 7, date: _dayThisMonth(9), description: 'Perbaikan AC kamar 201', category: 'Perbaikan Fasilitas', type: 'Pengeluaran', amount: 300000),
];

// Iuran dibuat otomatis dari data kamar yang terisi/dipesan
List<IuranData> iuranList = _seedIuran();

// Membuat data tagihan awal dari kamar yang sudah ada penghuninya
List<IuranData> _seedIuran() {
  final out = <IuranData>[];
  var n = 0;
  for (final r in rooms) {
    if (r.residentName == null) continue; // lewati kamar kosong
    final booked = r.status == 'Dipesan';
    // Kamar dipesan = belum bayar; kamar terisi = status bervariasi supaya demo menarik
    final st = booked ? stBelum : [stLunas, stLunas, stProses, stBelum][n % 4];
    n++;
    final bill = IuranData(
      id: n,
      residentName: r.residentName!,
      roomNumber: r.number,
      iuranType: booked ? 'Sewa 1 Bulan' : 'Iuran Bulanan',
      amount: monthlyBill(r),
      dueDate: formatDate(booked ? today.add(const Duration(days: 1)) : DateTime(2026, 10, 10)),
      status: st,
      paymentMethod: st == stBelum ? null : (n % 2 == 0 ? 'QRIS' : 'Transfer Bank'),
      isBooking: booked,
      bookingDeadline: booked ? DateTime.now().add(const Duration(hours: 24)) : null,
    );
    if (st == stLunas) bill.paidAt = DateTime(2026, 10, 1);
    out.add(bill);
  }
  return out;
}

// Daftar nama penghuni contoh (dipakai membuat akun)
const List<String> _residentNames = [
  'Gilbert', 'Andi', 'Budi', 'Citra', 'Dewi', 'Eko',
  'Fajar', 'Gita', 'Hendra', 'Indah', 'Joko', 'Kirana',
];

// Akun login (satu halaman login untuk semua; role ditentukan dari akun)
List<UserAccount> accounts = [
  // Akun admin: username 'admin', password '123'
  UserAccount(username: 'admin', password: '123', name: 'Admin', phone: ownerPhone, role: 'Admin'),
  // Akun penghuni contoh dibuat otomatis dari daftar nama (username = nama huruf kecil, password '123')
  ..._residentNames.asMap().entries.map((e) => UserAccount(
        username: e.value.toLowerCase(),
        password: '123',
        name: e.value,
        phone: '0812345670${10 + e.key}',
      )),
];

// Tipe kamar (bisa diedit admin lewat menu Kamar & Harga)
final List<RoomType> roomTypes = [
  RoomType(name: 'AC + WC Dalam', ac: true, wcDalam: true, price: 1500000, discount: 10),
  RoomType(name: 'AC + WC Luar', ac: true, wcDalam: false, price: 1100000),
  RoomType(name: 'Non-AC + WC Dalam', ac: false, wcDalam: true, price: 900000),
  RoomType(name: 'Non-AC + WC Luar', ac: false, wcDalam: false, price: 700000, discount: 15),
];

// Helper membuat kamar (kosong, atau terisi/dipesan dengan data penghuni)
// Parameter: nomor, tipe, nama penghuni, mulai berapa hari lalu, berakhir berapa hari lagi, status
Room _room(String no, int type, [String? name, int startAgo = 0, int endIn = 0, String status = 'Terisi']) {
  if (name == null) return Room(number: no, typeIndex: type);
  return Room(
    number: no,
    typeIndex: type,
    status: status,
    residentName: name,
    checkIn: today.subtract(Duration(days: startAgo)),
    checkOut: today.add(Duration(days: endIn)),
  );
}

// 20 kamar: 5 kamar untuk tiap tipe (index tipe: 0=AC+WC Dalam, 1=AC+WC Luar, 2=NonAC+WC Dalam, 3=NonAC+WC Luar)
List<Room> rooms = [
  _room('101', 0, 'Gilbert', 60, 120),
  _room('102', 0, 'Citra', 20, 160),
  _room('103', 0, 'Dewi', 150, 30),
  _room('104', 0),
  _room('105', 0),
  _room('201', 1, 'Andi', 80, 5),
  _room('202', 1, 'Eko', 45, 135),
  _room('203', 1, 'Fajar', 120, 60),
  _room('204', 1),
  _room('205', 1, 'Kirana', 0, 90, 'Dipesan'),
  _room('106', 2, 'Budi', 30, 60),
  _room('107', 2, 'Gita', 90, 3),
  _room('108', 2, 'Hendra', 10, 170),
  _room('109', 2),
  _room('110', 2),
  _room('206', 3, 'Indah', 15, 75),
  _room('207', 3, 'Joko', 200, 10),
  _room('208', 3),
  _room('209', 3),
  _room('210', 3),
];

// ---------- Fungsi bantu yang membaca data global ----------

// Tagihan per bulan = sewa (setelah diskon tipe) + listrik & air tetap
double monthlyBill(Room r) => roomTypes[r.typeIndex].finalPrice + utilityFee;

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
List<IuranData> iuranFor(UserAccount u) => iuranList
    .where((i) => i.residentName.toLowerCase() == u.name.toLowerCase())
    .toList();

// Kamar yang dimiliki / dipesan penghuni
Room? roomOf(UserAccount u) {
  for (final r in rooms) {
    if (r.residentName?.toLowerCase() == u.name.toLowerCase()) return r;
  }
  return null;
}

// Menambahkan notifikasi untuk admin
void addAdminNotification({
  required String type,
  required String title,
  required String message,
}) {
  adminNotifications.insert(0, AdminNotificationData(
    id: DateTime.now().microsecondsSinceEpoch,
    type: type,
    title: title,
    message: message,
    createdAt: DateTime.now(),
  ));
  notifyDataChanged();
}

// Menambahkan notifikasi untuk penghuni tertentu
void addResidentNotification({required String residentName, required String title, required String message}) {
  residentNotifications.insert(0, ResidentNotificationData(
    id: DateTime.now().microsecondsSinceEpoch,
    residentName: residentName,
    title: title,
    message: message,
    createdAt: DateTime.now(),
  ));
  notifyDataChanged();
}

// Notifikasi milik satu penghuni
List<ResidentNotificationData> notificationsFor(UserAccount user) => residentNotifications
    .where((n) => n.residentName.toLowerCase() == user.name.toLowerCase())
    .toList();
