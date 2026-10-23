// ============================================================
// MODEL DATA (cetakan data / class)
// ============================================================

import 'dart:typed_data'; // Uint8List: menyimpan data foto (bukti bayar, foto kerusakan)

import '../core/helpers.dart'; // today (dipakai Room.daysLeft)

// Data satu transaksi keuangan (pemasukan / pengeluaran)
class TransactionData {
  int id; // id unik (juga dipakai untuk mengurutkan dari yang terbaru)
  String date; // format dd/MM/yyyy
  String description; // keterangan transaksi
  String category; // kategori (lihat daftar kategori di constants.dart)
  String type; // 'Pemasukan' atau 'Pengeluaran'
  double amount; // nominal rupiah
  Uint8List? proofBytes; // foto bukti (opsional)
  int? sourceIuranId; // relasi ke tagihan agar pembatalan pembayaran konsisten

  TransactionData({
    required this.id,
    required this.date,
    required this.description,
    required this.category,
    required this.type,
    required this.amount,
    this.proofBytes,
    this.sourceIuranId,
  });
}

// Data satu tagihan (iuran / sewa) milik penghuni
class IuranData {
  int id;
  String residentName; // nama penghuni pemilik tagihan
  String roomNumber; // nomor kamar
  String iuranType; // jenis: Sewa 1 Bulan / Iuran Bulanan / Perpanjang ...
  double amount; // nominal tagihan
  String dueDate; // jatuh tempo (dd/MM/yyyy)
  String status; // stBelum / stProses / stLunas
  String? paymentMethod; // QRIS / Transfer Bank / Tunai
  Uint8List? proofBytes; // foto bukti transfer/QRIS
  String? proofSender; // nama pengirim / pemilik rekening
  String? rejectNote; // alasan jika ditolak admin
  DateTime? paidAt; // waktu dinyatakan lunas
  DateTime? bookingDeadline; // batas pembayaran booking (24 jam)
  bool isBooking; // tagihan pertama saat booking / walk-in
  int extendMonths; // > 0 = tagihan perpanjangan sewa

  IuranData({
    required this.id,
    required this.residentName,
    required this.roomNumber,
    required this.iuranType,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.paymentMethod,
    this.bookingDeadline,
    this.isBooking = false,
    this.extendMonths = 0,
  });
}

// Data akun pengguna (admin / penghuni)
class UserAccount {
  String username;
  String password;
  String name;
  String phone;
  String email;
  String role; // 'Admin' / 'Penghuni'

  UserAccount({
    required this.username,
    required this.password,
    required this.name,
    required this.phone,
    this.email = '',
    this.role = 'Penghuni',
  });
}

// Tipe kamar. Dibuat bisa diubah (tidak final) supaya admin dapat mengedit harga/diskon/fasilitas.
class RoomType {
  String name;
  bool ac;
  bool wcDalam;
  double price;
  int discount; // persen

  RoomType({
    required this.name,
    required this.ac,
    required this.wcDalam,
    required this.price,
    this.discount = 0,
  });

  // Harga sewa setelah diskon tipe kamar
  double get finalPrice => price * (100 - discount) / 100;
}

// Data satu kamar kos
class Room {
  String number; // nomor kamar
  int typeIndex; // index ke daftar roomTypes
  String status; // Kosong / Dipesan / Terisi
  String? residentName; // nama penghuni (null jika kosong)
  DateTime? checkIn; // tanggal mulai sewa
  DateTime? checkOut; // tanggal akhir sewa

  Room({
    required this.number,
    required this.typeIndex,
    this.status = 'Kosong',
    this.residentName,
    this.checkIn,
    this.checkOut,
  });

  // Sisa hari masa sewa (negatif jika sudah lewat)
  int? get daysLeft => checkOut?.difference(today).inDays;

  // Mengosongkan kamar
  void clear() {
    status = 'Kosong';
    residentName = null;
    checkIn = null;
    checkOut = null;
  }
}

// Data laporan kerusakan / komplain dari penghuni (punya kategori)
class ComplaintData {
  final int id;
  final String residentName;
  final String roomNumber;
  final String category; // Air / Listrik / AC / Lampu / Lainnya
  final String description; // alasan / detail kerusakan
  final DateTime createdAt;
  final Uint8List? photoBytes;
  String status; // Menunggu, Diproses, Selesai

  ComplaintData({
    required this.id,
    required this.residentName,
    required this.roomNumber,
    required this.category,
    required this.description,
    required this.createdAt,
    this.photoBytes,
    this.status = 'Menunggu',
  });
}

// Data pengumuman / peraturan kos
class AnnouncementData {
  final int id;
  final String title;
  final String body;
  final DateTime createdAt;

  AnnouncementData({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });
}

// Notifikasi untuk admin
class AdminNotificationData {
  final int id;
  final String type; // booking, payment, complaint, account
  final String title;
  final String message;
  final DateTime createdAt;
  bool isRead; // sudah dibaca atau belum

  AdminNotificationData({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });
}

// Notifikasi untuk penghuni
class ResidentNotificationData {
  final int id;
  final String residentName; // penerima notifikasi
  final String title;
  final String message;
  final DateTime createdAt;
  bool isRead;

  ResidentNotificationData({
    required this.id,
    required this.residentName,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });
}
