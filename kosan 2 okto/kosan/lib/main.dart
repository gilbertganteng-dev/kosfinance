// ============================================================
// KosFinance - Aplikasi Pencatat Keuangan & Pengelolaan Kos (Flutter Web)
// Dua peran: Admin (pemilik kos) dan Penghuni (calon penghuni / penghuni).
// Data disimpan di memori (List global) -> hilang saat aplikasi di-refresh.
// ============================================================

// ---------- IMPORT: library yang dipakai ----------
import 'package:flutter/material.dart'; // widget & tampilan Material Design
// Uint8List: menyimpan data foto (bukti bayar, foto kerusakan)
import 'package:flutter/services.dart'; // Clipboard: fitur salin nomor rekening
import 'package:image_picker/image_picker.dart'; // memilih foto dari galeri
import 'package:url_launcher/url_launcher.dart'; // membuka WhatsApp & Google Maps
import 'package:pdf/widgets.dart' as pw; // membuat dokumen PDF (kuitansi)
import 'package:printing/printing.dart'; // dialog cetak / unduh PDF

// Titik awal aplikasi: menjalankan widget utama KosFinanceApp
void main() {
  runApp(const KosFinanceApp());
}

// ============================================================
// COLORS & KONSTANTA
// ============================================================

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

// ============================================================
// MODEL DATA (cetakan data / class)
// ============================================================

// Data satu transaksi keuangan (pemasukan / pengeluaran)
class TransactionData {
  int id; // id unik (juga dipakai untuk mengurutkan dari yang terbaru)
  String date; // format dd/MM/yyyy
  String description; // keterangan transaksi
  String category; // kategori (lihat daftar kategori di atas)
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

// ============================================================
// DATA GLOBAL (dummy, disimpan di memori)
// ============================================================

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

// ============================================================
// HELPER (fungsi bantu yang dipakai di banyak tempat)
// ============================================================

// Tanggal hari ini tanpa jam
DateTime get today {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

// Menambah bulan pada tanggal
DateTime addMonths(DateTime d, int m) => DateTime(d.year, d.month + m, d.day);

// Format tanggal dd/MM/yyyy
String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// Format tanggal + jam
String formatDateTime(DateTime d) =>
    '${formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// Membaca teks dd/MM/yyyy menjadi DateTime (null jika format salah)
DateTime? parseDate(String s) {
  try {
    final parts = s.split('/');
    if (parts.length != 3) return null;
    return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
  } catch (_) {
    return null;
  }
}

// Nama bulan + tahun, contoh "Oktober 2026"
String monthLabel(DateTime month) {
  const names = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
  return '${names[month.month - 1]} ${month.year}';
}

// Format angka ke Rupiah, contoh Rp 1.500.000
String formatRupiah(double value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp $buf';
}

// Tagihan per bulan = sewa (setelah diskon tipe) + listrik & air tetap
double monthlyBill(Room r) => roomTypes[r.typeIndex].finalPrice + utilityFee;

// Mencari kamar yang terkait dengan sebuah tagihan
Room? _roomFor(IuranData i) {
  for (final r in rooms) {
    if (r.number == i.roomNumber && r.residentName == i.residentName) return r;
  }
  return null;
}

// Membaca tanggal transaksi dengan format dd/MM/yyyy.
DateTime? transactionDate(TransactionData transaction) => parseDate(transaction.date);

// Cek apakah transaksi berada di bulan tertentu
bool transactionInMonth(TransactionData transaction, DateTime month) {
  final date = transactionDate(transaction);
  return date != null && date.year == month.year && date.month == month.month;
}

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

// Ikon untuk tiap kategori pengeluaran
IconData expenseIcon(String category) {
  switch (category) {
    case 'Listrik':
      return Icons.bolt_outlined;
    case 'Air':
      return Icons.water_drop_outlined;
    case 'WiFi / Internet':
      return Icons.wifi;
    case 'Gaji Penjaga':
      return Icons.security_outlined;
    case 'Lampu & Penerangan':
      return Icons.lightbulb_outline;
    case 'Perbaikan Fasilitas':
      return Icons.build_outlined;
    default:
      return Icons.more_horiz;
  }
}

// Membuka WhatsApp pemilik kos
Future<void> openWhatsApp(BuildContext context, {String message = 'Halo, saya ingin bertanya tentang kos.'}) async {
  final rawPhone = ownerPhone.replaceAll(RegExp(r'\D'), ''); // buang karakter non-angka
  // Nomor Indonesia yang diawali 0 diubah ke kode negara 62 untuk WhatsApp.
  final phone = rawPhone.startsWith('0') ? '62${rawPhone.substring(1)}' : rawPhone;
  final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) showMessage(context, 'Tidak dapat membuka WhatsApp. Periksa nomor pemilik kos.');
  }
}

// Membuka lokasi kos (STMIK LIKMI Bandung) di Google Maps
Future<void> openKosMap(BuildContext context) async {
  final uri = Uri.parse(kosMapUrl);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) showMessage(context, 'Tidak dapat membuka Google Maps.');
  }
}

// Menampilkan snackbar pesan singkat di bawah layar
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

// Warna sesuai status pembayaran
Color statusColor(String s) =>
    s == stLunas ? Colors.green : (s == stProses ? Colors.blue : (s == stKadaluarsa ? Colors.grey : Colors.orange));

// Warna sesuai status kamar
Color roomColor(String s) =>
    s == 'Kosong' ? Colors.green : (s == 'Dipesan' ? Colors.orange : Colors.blueGrey);

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

// Tagihan terlambat = belum dibayar dan tanggal jatuh tempo sudah lewat
bool isOverdue(IuranData i) {
  if (i.status != stBelum) return false;
  final due = parseDate(i.dueDate);
  return due != null && due.isBefore(today);
}

// Teks keterangan jatuh tempo (dipakai admin & penghuni, menggantikan menu Pengingat terpisah)
String dueLabel(IuranData i) {
  if (i.status == stProses) return 'Menunggu konfirmasi pemilik kos';
  if (i.status == stLunas) return 'Sudah lunas';
  if (i.isBooking && i.bookingDeadline != null) {
    final left = i.bookingDeadline!.difference(DateTime.now());
    if (left.isNegative) return 'Batas pembayaran booking sudah lewat';
    return 'Bayar sebelum ${formatDateTime(i.bookingDeadline!)} (sisa ${left.inHours} jam)';
  }
  final due = parseDate(i.dueDate);
  if (due == null) return 'Jatuh tempo ${i.dueDate}';
  final d = due.difference(today).inDays;
  if (d < 0) return 'Terlambat ${-d} hari';
  if (d == 0) return 'Jatuh tempo hari ini';
  return '$d hari lagi (${i.dueDate})';
}

// Ikon untuk tiap kategori laporan kerusakan
IconData complaintIcon(String category) {
  switch (category) {
    case 'Air':
      return Icons.water_drop_outlined;
    case 'Listrik':
      return Icons.bolt_outlined;
    case 'AC':
      return Icons.ac_unit;
    case 'Lampu':
      return Icons.lightbulb_outline;
    default:
      return Icons.more_horiz;
  }
}

// Contoh isi alasan untuk tiap kategori (hint di kolom deskripsi)
String complaintHint(String category) {
  switch (category) {
    case 'Air':
      return 'Contoh: air kamar mandi mati / keran bocor / air keruh.';
    case 'Listrik':
      return 'Contoh: stop kontak mati / listrik sering turun.';
    case 'AC':
      return 'Contoh: AC dingin terus dan suhunya tidak bisa dinaikkan.';
    case 'Lampu':
      return 'Contoh: lampu kamar mati atau berkedip.';
    default:
      return 'Tulis kerusakan atau komplain Anda dengan jelas (kasur, pintu, dll).';
  }
}

// Daftar kategori transaksi sesuai jenis (pemasukan/pengeluaran).
// Jika transaksi lama punya kategori di luar daftar, kategori itu tetap ditampilkan.
List<String> categoriesFor(String type, [String? current]) {
  final base = type == 'Pemasukan' ? incomeCategories : expenseCategories;
  if (current != null && current.isNotEmpty && !base.contains(current)) {
    return [...base, current];
  }
  return base;
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

// Mencatat pemasukan otomatis dari tagihan yang lunas
void addIncomeFor(IuranData i) {
  transactions.removeWhere((t) => t.sourceIuranId == i.id); // hindari catatan ganda
  transactions.add(TransactionData(
    id: DateTime.now().millisecondsSinceEpoch,
    date: formatDate(today),
    description: 'Pembayaran ${i.iuranType} ${i.residentName}',
    category: 'Iuran',
    type: 'Pemasukan',
    amount: i.amount,
    proofBytes: i.proofBytes,
    sourceIuranId: i.id,
  ));
}

// Menandai tagihan lunas (dipakai admin saat konfirmasi / bayar langsung)
void markPaid(IuranData i) {
  final wasPaid = i.status == stLunas;
  i.status = stLunas;
  i.rejectNote = null;
  i.paidAt ??= DateTime.now();
  addIncomeFor(i); // otomatis jadi pemasukan

  if (!wasPaid) {
    var extra = '';
    final room = _roomFor(i);
    // Kamar baru AKTIF setelah booking lunas 100%
    if (i.isBooking && room != null && room.status == 'Dipesan') {
      room.status = 'Terisi';
      extra = ' Kamar ${room.number} sekarang aktif.';
    }
    // Masa sewa bertambah hanya setelah perpanjangan lunas
    if (i.extendMonths > 0 && room != null && room.status == 'Terisi') {
      room.checkOut = addMonths(room.checkOut ?? today, i.extendMonths);
      extra = ' Masa sewa diperpanjang.';
    }
    addResidentNotification(
      residentName: i.residentName,
      title: 'Pembayaran dikonfirmasi',
      message: 'Pembayaran ${i.iuranType} sebesar ${formatRupiah(i.amount)} sudah lunas.$extra',
    );
  }
  notifyDataChanged();
}

// Membatalkan status lunas (pemasukan terkait ikut dihapus)
void markUnpaid(IuranData i) {
  final wasPaid = i.status == stLunas;
  transactions.removeWhere((t) => t.sourceIuranId == i.id);
  i.status = stBelum;
  i.paidAt = null;
  i.paymentMethod = null;
  i.proofBytes = null;
  i.proofSender = null;

  if (wasPaid) {
    final room = _roomFor(i);
    if (room != null) {
      if (i.isBooking && room.status == 'Terisi') {
        room.status = 'Dipesan';
        i.bookingDeadline = DateTime.now().add(const Duration(hours: 24));
      }
      if (i.extendMonths > 0 && room.checkOut != null) {
        room.checkOut = addMonths(room.checkOut!, -i.extendMonths);
      }
    }
  }
  notifyDataChanged();
}

// Membatalkan booking yang tidak dibayar dalam 24 jam.
// Dipanggil dari build() => notify:false supaya tidak error "setState during build".
void expireBookingReservations({bool notify = true}) {
  final now = DateTime.now();
  // Hanya yang belum bayar sama sekali. Yang sudah kirim bukti (menunggu konfirmasi) tidak dibatalkan.
  final expired = iuranList.where((i) =>
      i.isBooking &&
      i.bookingDeadline != null &&
      i.status == stBelum &&
      now.isAfter(i.bookingDeadline!)).toList();

  for (final bill in expired) {
    final room = _roomFor(bill);
    if (room != null && room.status == 'Dipesan') room.clear(); // kamar kembali kosong
    residentNotifications.insert(0, ResidentNotificationData(
      id: DateTime.now().microsecondsSinceEpoch,
      residentName: bill.residentName,
      title: 'Booking kadaluarsa',
      message: 'Booking kamar ${bill.roomNumber} dibatalkan karena belum dibayar lunas dalam 24 jam.',
      createdAt: DateTime.now(),
    ));
    iuranList.remove(bill);
  }
  if (expired.isNotEmpty && notify) notifyDataChanged();
}

// Dialog konfirmasi Ya/Batal
Future<bool> confirmAction(BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, Lanjutkan')),
      ],
    ),
  );
  return result == true;
}

// Membuat tagihan baru (booking / perpanjangan / iuran bulanan)
IuranData createIuran(
  Room r,
  String name,
  DateTime due, {
  int months = 1,
  bool booking = false,
  int extend = 0,
}) {
  final bill = IuranData(
    id: DateTime.now().microsecondsSinceEpoch,
    residentName: name,
    roomNumber: r.number,
    iuranType: booking
        ? 'Sewa $months Bulan'
        : (extend > 0 ? 'Perpanjang $extend Bulan' : 'Iuran Bulanan'),
    amount: monthlyBill(r) * months,
    dueDate: formatDate(due),
    status: stBelum,
    isBooking: booking,
    extendMonths: extend,
    bookingDeadline: booking ? DateTime.now().add(const Duration(hours: 24)) : null,
  );
  iuranList.add(bill);
  return bill;
}

// Kolom input teks dengan ikon (dipakai di banyak form)
Widget field(
  TextEditingController c,
  String label,
  IconData icon, {
  bool obscure = false,
  TextInputType? type,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    ),
  );
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

// ============================================================
// LOGIN (tanpa pilihan role)
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController(); // isi kolom username
  final passwordController = TextEditingController(); // isi kolom password
  bool obscurePassword = true; // true = password disembunyikan

  // Proses login: cek username & password, lalu arahkan sesuai role akun
  void login() {
    final u = usernameController.text.trim().toLowerCase();
    final p = passwordController.text;
    final found = accounts.where((a) => a.username == u && a.password == p);

    if (found.isEmpty) {
      showMessage(context, 'Username atau password salah.');
      return;
    }

    final acc = found.first;
    // pushReplacement: halaman login diganti dashboard (tombol back tidak kembali ke login)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => acc.role == 'Admin'
            ? const AdminDashboard()
            : CustomerDashboard(user: acc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryGreen,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // Logo aplikasi
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: lightGreen,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.account_balance_wallet, size: 45, color: primaryGreen),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'KosFinance', // untuk nama judul pada halaman utama
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: primaryGreen),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pencatat Keuangan & Pengelolaan Kos',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  // Input username
                  TextField(
                    controller: usernameController,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: const [],
                    decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  // Input password (ikon mata untuk tampil/sembunyi)
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: const [],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                  ),
                  // Tombol lupa password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                      ),
                      child: const Text('Lupa password?'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Tombol login
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Tombol daftar akun baru
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()),
                      ).then((_) {
                        // Setelah kembali dari halaman daftar, kosongkan kolom login
                        if (mounted) {
                          usernameController.clear();
                          passwordController.clear();
                        }
                      }),
                      child: const Text('Daftar Akun Baru'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Pengunjung bisa melihat kamar & harga tanpa login
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RoomListPage()),
                    ),
                    icon: const Icon(Icons.local_offer_outlined),
                    label: const Text('Lihat Kamar & Harga'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// REGISTRASI AKUN
// ============================================================

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameC = TextEditingController();
  final userC = TextEditingController();
  final phoneC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final pass2C = TextEditingController();

  // Validasi form lalu simpan akun baru
  void register() {
    final name = nameC.text.trim();
    final user = userC.text.trim().toLowerCase();
    final phone = phoneC.text.trim();

    // 1. Kolom wajib tidak boleh kosong
    if (name.isEmpty || user.isEmpty || phone.isEmpty || passC.text.isEmpty) {
      showMessage(context, 'Nama, username, no. HP, dan password wajib diisi.');
      return;
    }
    if (passC.text.length < 3) {
      showMessage(context, 'Password minimal 3 karakter.');
      return;
    }
    if (passC.text != pass2C.text) {
      showMessage(context, 'Konfirmasi password tidak sama.');
      return;
    }
    // 2. Username harus unik
    if (accounts.any((a) => a.username == user)) {
      showMessage(context, 'Username sudah dipakai.');
      return;
    }
    // 3. Nama juga harus unik, karena nama dipakai untuk mengaitkan kamar & tagihan ke akun
    if (accounts.any((a) => a.name.toLowerCase() == name.toLowerCase())) {
      showMessage(context, 'Nama sudah terdaftar. Gunakan nama lain agar kamar & tagihan tidak tertukar.');
      return;
    }

    accounts.add(UserAccount(
      username: user,
      password: passC.text,
      name: name,
      phone: phone,
      email: emailC.text.trim(),
    ));
    // Admin diberi tahu ada akun baru
    addAdminNotification(
      type: 'account',
      title: 'Pendaftaran akun baru',
      message: '$name baru saja membuat akun penghuni.',
    );

    showMessage(context, 'Registrasi berhasil. Silakan login.');
    Navigator.pop(context); // kembali ke halaman login
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrasi Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(nameC, 'Nama Lengkap', Icons.badge_outlined),
          field(userC, 'Username', Icons.person_outline),
          field(phoneC, 'Nomor HP', Icons.phone_outlined, type: TextInputType.phone),
          field(emailC, 'Email (opsional)', Icons.email_outlined, type: TextInputType.emailAddress),
          field(passC, 'Password', Icons.lock_outline, obscure: true),
          field(pass2C, 'Konfirmasi Password', Icons.lock_reset_outlined, obscure: true),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: register,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: const Text('DAFTAR'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LUPA PASSWORD
// ============================================================

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final userC = TextEditingController();
  final phoneC = TextEditingController();
  final passC = TextEditingController();
  final pass2C = TextEditingController();

  // Verifikasi username + nomor HP, lalu ganti password
  void reset() {
    final user = userC.text.trim().toLowerCase();
    final found = accounts.where((a) => a.username == user && a.phone == phoneC.text.trim());

    if (found.isEmpty) {
      showMessage(context, 'Username atau nomor HP tidak cocok.');
      return;
    }
    if (passC.text.length < 3) {
      showMessage(context, 'Password baru minimal 3 karakter.');
      return;
    }
    if (passC.text != pass2C.text) {
      showMessage(context, 'Konfirmasi password tidak sama.');
      return;
    }

    found.first.password = passC.text; // simpan password baru
    showMessage(context, 'Password berhasil diubah. Silakan login.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lupa Password')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Masukkan username dan nomor HP yang terdaftar untuk verifikasi, lalu buat password baru.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          field(userC, 'Username', Icons.person_outline),
          field(phoneC, 'Nomor HP terdaftar', Icons.phone_outlined, type: TextInputType.phone),
          field(passC, 'Password Baru', Icons.lock_outline, obscure: true),
          field(pass2C, 'Konfirmasi Password Baru', Icons.lock_reset_outlined, obscure: true),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: reset,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: const Text('UBAH PASSWORD'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// KAMAR & HARGA
// - user != null  -> calon penghuni / penghuni (boleh booking)
// - isAdmin true  -> admin (boleh EDIT tipe, harga, diskon, tarif listrik & air)
// - keduanya kosong -> pengunjung (hanya melihat)
// ============================================================

class RoomListPage extends StatefulWidget {
  final UserAccount? user;
  final bool isAdmin;

  const RoomListPage({super.key, this.user, this.isAdmin = false});

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  // Foto contoh tiap tipe kamar (diambil dari internet)
  static const photos = [
    'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?w=1000',
    'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=1000',
    'https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=1000',
    'https://images.unsplash.com/photo-1616486029423-aaa4789e8c9a?w=1000',
  ];

  // Membuka halaman booking untuk kamar yang dipilih
  void bookRoom(Room room) {
    final user = widget.user;
    if (user == null) {
      showMessage(context, 'Login atau daftar akun penghuni dulu untuk booking.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingPage(room: room, user: user)),
    ).then((_) => setState(() {})); // segarkan daftar kamar setelah booking
  }

  // ---------- ADMIN: edit tipe kamar (nama, fasilitas, harga, diskon) ----------
  Future<void> editType(int index) async {
    final t = roomTypes[index];
    final nameC = TextEditingController(text: t.name);
    final priceC = TextEditingController(text: t.price.toStringAsFixed(0));
    final discC = TextEditingController(text: '${t.discount}');
    bool ac = t.ac;
    bool wc = t.wcDalam;

    final ok = await showDialog<bool>(
      context: context,
      // StatefulBuilder: supaya switch di dalam dialog bisa berubah tampilannya
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Edit Tipe Kamar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field(nameC, 'Nama tipe', Icons.bedroom_parent_outlined),
                field(priceC, 'Harga sewa / bulan', Icons.payments_outlined, type: TextInputType.number),
                field(discC, 'Diskon (%)', Icons.percent, type: TextInputType.number),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ber-AC'),
                  value: ac,
                  onChanged: (v) => setDialog(() => ac = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('WC Dalam'),
                  value: wc,
                  onChanged: (v) => setDialog(() => wc = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );

    if (ok != true) return; // dibatalkan
    // Validasi input: harga > 0 dan diskon 0-100
    final price = double.tryParse(priceC.text.trim()) ?? 0;
    final disc = int.tryParse(discC.text.trim()) ?? -1;
    if (nameC.text.trim().isEmpty || price <= 0 || disc < 0 || disc > 100) {
      if (mounted) showMessage(context, 'Data tidak valid. Harga harus > 0 dan diskon 0-100%.');
      return;
    }

    setState(() {
      t.name = nameC.text.trim();
      t.price = price;
      t.discount = disc;
      t.ac = ac;
      t.wcDalam = wc;
    });
    notifyDataChanged();
    if (mounted) showMessage(context, 'Tipe kamar diperbarui. Tagihan yang sudah dibuat tidak berubah.');
  }

  // ---------- ADMIN: edit tarif listrik & air per bulan ----------
  Future<void> editUtilityFee() async {
    final c = TextEditingController(text: utilityFee.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tarif Listrik & Air'),
        content: field(c, 'Tarif tetap / bulan', Icons.bolt_outlined, type: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    final v = double.tryParse(c.text.trim()) ?? 0;
    if (v < 0) {
      if (mounted) showMessage(context, 'Nominal tidak valid.');
      return;
    }
    setState(() => utilityFee = v);
    notifyDataChanged();
    if (mounted) showMessage(context, 'Tarif listrik & air diperbarui.');
  }

  // Chip kecil nomor kamar + status (hijau = bisa dibooking)
  Widget roomChip(Room r) {
    final c = roomColor(r.status);
    final canBook = r.status == 'Kosong' && !widget.isAdmin;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: canBook ? () => bookRoom(r) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.5)),
        ),
        child: Text(
          '${r.number} • ${r.status}',
          style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    expireBookingReservations(notify: false); // bersihkan booking kadaluarsa
    // Diskon terbesar dari semua tipe (untuk teks banner promo)
    final maxDisc = roomTypes.map((t) => t.discount).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: Text(widget.isAdmin ? 'Kamar & Harga (Admin)' : 'Cek Kamar & Harga')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner promo
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    maxDisc > 0
                        ? 'Promo! Diskon hingga $maxDisc% untuk tipe kamar pilihan. Pembayaran booking harus lunas 100%.'
                        : 'Pembayaran booking harus lunas 100%. Listrik & air sudah termasuk di tagihan.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Info untuk pengunjung yang belum login
          if (widget.user == null && !widget.isAdmin)
            const Card(
              color: lightGreen,
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Untuk booking kamar, silakan login atau daftar akun terlebih dahulu.'),
              ),
            ),
          // Panel khusus admin: info edit + tarif listrik & air
          if (widget.isAdmin)
            Card(
              color: lightGreen,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_outlined, color: primaryGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tarif Listrik & Air (tetap)', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${formatRupiah(utilityFee)} / bulan • sudah masuk tagihan kamar'),
                          const Text('Ketuk ikon pensil di tiap tipe untuk mengubah harga/diskon.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: editUtilityFee, icon: const Icon(Icons.edit_outlined)),
                  ],
                ),
              ),
            ),
          // Kartu promo hemat
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Promo Hemat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.savings_outlined, color: primaryGreen),
                    title: Text('Sewa 6 bulan di muka'),
                    subtitle: Text('Diskon tambahan 8% dari sewa.'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.workspace_premium_outlined, color: primaryGreen),
                    title: Text('Sewa 12 bulan di muka'),
                    subtitle: Text('Diskon tambahan 15% dari sewa.'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.confirmation_number_outlined, color: primaryGreen),
                    title: Text('Voucher KOSHEMAT5 / AJAKTEMAN10'),
                    subtitle: Text('Diskon 5% / 10%. Masukkan kode saat booking.'),
                  ),
                  Text(
                    'Promo pada versi demo belum terhubung ke backend. Listrik & air tidak kena diskon.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          // Lokasi kos
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined, color: primaryGreen),
              title: const Text('Lokasi Kos', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(kosLocationName),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openKosMap(context),
            ),
          ),
          const SizedBox(height: 4),
          // Tombol WhatsApp & lokasi
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => openWhatsApp(context, message: 'Halo, saya ingin bertanya tentang harga dan ketersediaan kamar kos.'),
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp Pemilik'),
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              ),
              OutlinedButton.icon(
                onPressed: () => openKosMap(context),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Buka Google Maps'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Kartu per tipe kamar (dibuat otomatis dari daftar roomTypes)
          ...List.generate(roomTypes.length, (i) {
            final t = roomTypes[i];
            final typeRooms = rooms.where((r) => r.typeIndex == i).toList();
            final vacant = vacantCount(i);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto kamar (ada fallback ikon jika gagal dimuat)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photos[i % photos.length],
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 150,
                          color: lightGreen,
                          child: const Center(child: Icon(Icons.bedroom_parent_outlined, size: 56, color: primaryGreen)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Nama tipe + diskon + tombol edit (khusus admin)
                    Row(
                      children: [
                        Expanded(child: Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        if (t.discount > 0) Pill(text: 'Diskon ${t.discount}%', color: Colors.red),
                        if (widget.isAdmin)
                          IconButton(
                            tooltip: 'Edit tipe kamar',
                            onPressed: () => editType(i),
                            icon: const Icon(Icons.edit_outlined, color: primaryGreen),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        Pill(text: t.ac ? 'Ber-AC' : 'Tanpa AC', color: Colors.blue),
                        Pill(text: t.wcDalam ? 'WC Dalam' : 'WC Luar', color: Colors.teal),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Harga coret jika ada diskon
                    if (t.discount > 0)
                      Text(formatRupiah(t.price), style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
                    Text(
                      '${formatRupiah(t.finalPrice)} / bulan',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
                    ),
                    Text(
                      '+ Listrik & air ${formatRupiah(utilityFee)} / bulan',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      vacant > 0 ? '$vacant dari ${typeRooms.length} kamar kosong' : 'Penuh',
                      style: TextStyle(color: vacant > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: typeRooms.map(roomChip).toList()),
                    if (widget.user != null && vacant > 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Ketuk kamar berwarna hijau untuk booking.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================
// BOOKING (listrik & air sudah masuk di total)
// ============================================================

class BookingPage extends StatefulWidget {
  final Room room; // kamar yang dipesan
  final UserAccount user; // penghuni yang memesan

  const BookingPage({super.key, required this.room, required this.user});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime start = today; // tanggal masuk
  int months = 1; // durasi sewa (bulan)
  final voucherC = TextEditingController();
  String appliedVoucher = ''; // kode voucher yang sah

  // Perhitungan diskon & total
  double get durationDiscount => months >= 12 ? 0.15 : (months >= 6 ? 0.08 : 0.0); // diskon durasi
  double get voucherDiscount => appliedVoucher == 'KOSHEMAT5' ? 0.05 : (appliedVoucher == 'AJAKTEMAN10' ? 0.10 : 0.0);
  double get rentSubtotal => roomTypes[widget.room.typeIndex].finalPrice * months; // sewa sebelum diskon tambahan
  double get rentTotal => rentSubtotal * (1 - durationDiscount) * (1 - voucherDiscount); // sewa setelah diskon
  double get utilityTotal => utilityFee * months; // listrik & air (tidak kena diskon)
  double get grandTotal => rentTotal + utilityTotal; // total yang harus dibayar lunas

  // Memeriksa kode voucher
  void applyVoucher() {
    final code = voucherC.text.trim().toUpperCase();
    if (code == 'KOSHEMAT5' || code == 'AJAKTEMAN10') {
      setState(() => appliedVoucher = code);
      showMessage(context, 'Voucher $code berhasil digunakan.');
    } else {
      setState(() => appliedVoucher = '');
      showMessage(context, 'Kode voucher tidak valid.');
    }
  }

  // Memilih tanggal masuk
  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => start = picked);
  }

  // Konfirmasi booking: kamar jadi "Dipesan" dan tagihan dibuat
  void confirm() {
    final room = widget.room;

    // Satu penghuni hanya boleh punya satu kamar
    if (roomOf(widget.user) != null) {
      showMessage(context, 'Anda sudah memiliki kamar atau booking aktif.');
      return;
    }
    // Pastikan kamar belum diambil orang lain
    if (room.status != 'Kosong') {
      showMessage(context, 'Maaf, kamar ini sudah tidak tersedia.');
      return;
    }

    // Status "Dipesan" = BELUM aktif. Baru jadi "Terisi" setelah lunas dikonfirmasi (lihat markPaid).
    room.status = 'Dipesan';
    room.residentName = widget.user.name;
    room.checkIn = start;
    room.checkOut = addMonths(start, months);
    iuranList.add(IuranData(
      id: DateTime.now().millisecondsSinceEpoch,
      residentName: widget.user.name,
      roomNumber: room.number,
      iuranType: 'Sewa $months Bulan',
      amount: grandTotal,
      dueDate: formatDate(today.add(const Duration(days: 1))),
      status: stBelum,
      isBooking: true,
      bookingDeadline: DateTime.now().add(const Duration(hours: 24)), // batas bayar 24 jam
    ));
    addAdminNotification(
      type: 'booking',
      title: 'Booking kamar baru',
      message: '${widget.user.name} mengajukan booking kamar ${room.number}.',
    );

    notifyDataChanged();
    showMessage(context, 'Booking berhasil. Bayar LUNAS 100% dalam 24 jam di dashboard. Kamar aktif setelah pembayaran dikonfirmasi.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final type = roomTypes[room.typeIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Booking Kamar ${room.number}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RoomCard(room: room),
          const SizedBox(height: 8),
          // Pilih tanggal masuk
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today_outlined, color: primaryGreen),
              title: const Text('Tanggal Masuk'),
              subtitle: Text(formatDate(start)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: pickDate,
            ),
          ),
          const SizedBox(height: 8),
          // Pilih durasi sewa
          DropdownButtonFormField<int>(
            initialValue: months,
            decoration: const InputDecoration(labelText: 'Durasi Sewa', prefixIcon: Icon(Icons.timelapse_outlined)),
            items: const [1, 3, 6, 12].map((m) => DropdownMenuItem(value: m, child: Text('$m bulan'))).toList(),
            onChanged: (v) => setState(() => months = v!),
          ),
          const SizedBox(height: 12),
          // Input voucher
          TextField(
            controller: voucherC,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Kode Voucher (opsional)',
              hintText: 'KOSHEMAT5 / AJAKTEMAN10',
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
              suffixIcon: TextButton(onPressed: applyVoucher, child: const Text('Pakai')),
            ),
          ),
          const SizedBox(height: 8),
          // Rincian biaya
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InfoRow(label: 'Sewa / bulan', value: formatRupiah(type.finalPrice)),
                  InfoRow(label: 'Durasi sewa', value: '$months bulan'),
                  InfoRow(label: 'Selesai sewa', value: formatDate(addMonths(start, months))),
                  InfoRow(label: 'Subtotal sewa', value: formatRupiah(rentSubtotal)),
                  InfoRow(label: 'Diskon durasi', value: '${(durationDiscount * 100).round()}%'),
                  InfoRow(label: 'Diskon voucher', value: '${(voucherDiscount * 100).round()}%'),
                  if (appliedVoucher.isNotEmpty) InfoRow(label: 'Voucher', value: appliedVoucher),
                  InfoRow(label: 'Sewa setelah diskon', value: formatRupiah(rentTotal)),
                  InfoRow(label: 'Listrik & air ($months bln)', value: formatRupiah(utilityTotal)),
                  const Divider(),
                  InfoRow(label: 'TOTAL BAYAR (LUNAS)', value: formatRupiah(grandTotal)),
                  const SizedBox(height: 6),
                  const Text(
                    'Listrik & air sudah termasuk dalam tagihan (tarif tetap), jadi tidak perlu input meter. '
                    'Pembayaran harus lunas 100% (tidak bisa dicicil) dalam 24 jam. '
                    'Kamar baru aktif setelah pembayaran dikonfirmasi pemilik kos.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: confirm,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: const Text('KONFIRMASI BOOKING'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ADMIN DASHBOARD
// Urutan: Notifikasi -> Ringkasan Keuangan -> Grafik -> Pengeluaran per Kategori -> Transaksi Terbaru
// ============================================================

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    // Dengarkan perubahan data agar dashboard selalu terbaru
    appDataRevision.addListener(_refreshFromSharedData);
  }

  void _refreshFromSharedData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_refreshFromSharedData); // wajib dilepas agar tidak bocor memori
    super.dispose();
  }

  // Ringkasan keuangan bulan ini
  double get totalIncome => transactions
      .where((item) => item.type == 'Pemasukan' && transactionInMonth(item, today))
      .fold(0.0, (sum, item) => sum + item.amount);

  double get totalExpense => transactions
      .where((item) => item.type == 'Pengeluaran' && transactionInMonth(item, today))
      .fold(0.0, (sum, item) => sum + item.amount);

  double get balance => totalIncome - totalExpense; // saldo = pemasukan - pengeluaran

  int get unpaidIuran => iuranList.where((i) => i.status == stBelum).length;

  int get waitingIuran => iuranList.where((i) => i.status == stProses).length;
  int get unreadNotificationCount => adminNotifications.where((n) => !n.isRead).length;

  // Ikon notifikasi sesuai jenisnya
  IconData _notificationIcon(String type) {
    switch (type) {
      case 'payment': return Icons.payments_outlined;
      case 'booking': return Icons.meeting_room_outlined;
      case 'complaint': return Icons.build_outlined;
      default: return Icons.person_add_alt_outlined;
    }
  }

  // Ketuk notifikasi -> tandai dibaca lalu buka halaman terkait
  Future<void> _openNotification(AdminNotificationData notification) async {
    setState(() => notification.isRead = true);
    Widget page;
    switch (notification.type) {
      case 'payment':
        page = const IuranPage();
        break;
      case 'booking':
        page = const AdminRoomPage();
        break;
      case 'account':
        page = const RegisteredUsersPage();
        break;
      case 'complaint':
        page = const ComplaintsPage(isAdmin: true);
        break;
      default:
        page = const IuranPage();
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  // Kartu notifikasi aktivitas (5 terbaru)
  Widget _notificationsSection() {
    final latest = adminNotifications.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.notifications_active_outlined, color: primaryGreen),
              const SizedBox(width: 8),
              const Expanded(child: Text('Notifikasi Aktivitas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              // Lencana merah jumlah notifikasi belum dibaca
              if (unreadNotificationCount > 0)
                CircleAvatar(radius: 13, backgroundColor: Colors.red, child: Text('$unreadNotificationCount', style: const TextStyle(color: Colors.white, fontSize: 12))),
            ]),
            const SizedBox(height: 8),
            if (latest.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Belum ada aktivitas baru dari penghuni atau calon penghuni.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...latest.map((notification) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: notification.isRead ? Colors.grey.shade100 : lightGreen,
                  child: Icon(_notificationIcon(notification.type), color: notification.isRead ? Colors.grey : primaryGreen),
                ),
                title: Text(notification.title, style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text('${notification.message}\n${formatDateTime(notification.createdAt)}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openNotification(notification),
              )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    expireBookingReservations(notify: false);
    // Nilai terbesar dipakai sebagai skala panjang bar grafik
    final maxAmount = totalIncome > totalExpense ? totalIncome : totalExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      drawer: const AdminDrawer(), // menu samping
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}), // tarik ke bawah untuk menyegarkan
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Notifikasi
            _notificationsSection(),
            const SizedBox(height: 14),
            // 2. Ringkasan keuangan
            const Text('Ringkasan Keuangan', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('Pantau kondisi keuangan kos bulan ini.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(title: 'Pemasukan', value: formatRupiah(totalIncome), icon: Icons.trending_up, color: Colors.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(title: 'Pengeluaran', value: formatRupiah(totalExpense), icon: Icons.trending_down, color: Colors.red),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(title: 'Saldo', value: formatRupiah(balance), icon: Icons.account_balance_wallet, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(title: 'Belum Dibayar', value: '$unpaidIuran', icon: Icons.notifications_none, color: Colors.orange),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(title: 'Perlu Konfirmasi', value: '$waitingIuran', icon: Icons.hourglass_top, color: Colors.indigo),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(title: 'Kamar Kosong', value: '${vacantCount()}', icon: Icons.meeting_room_outlined, color: Colors.teal),
                ),
              ],
            ),
            const SizedBox(height: 22),
            // 3. Grafik batang pemasukan vs pengeluaran
            SectionTitle(
              title: 'Grafik Keuangan',
              actionText: 'Lihat',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportPage()),
              ),
            ),
            const SizedBox(height: 10),
            FinancialBar(title: 'Pemasukan', amount: totalIncome, maxAmount: maxAmount, color: Colors.green),
            FinancialBar(title: 'Pengeluaran', amount: totalExpense, maxAmount: maxAmount, color: Colors.red),
            const SizedBox(height: 10),
            // 4. Pengeluaran bulan ini dirinci per kategori (listrik, wifi, penjaga, dst.)
            ExpenseBreakdownCard(month: today),
            const SizedBox(height: 10),
            // 5. Transaksi terbaru (3 teratas)
            const SectionTitle(title: 'Transaksi Terbaru'),
            const SizedBox(height: 8),
            ...(List<TransactionData>.from(transactions)..sort((a, b) => b.id.compareTo(a.id))).take(3).map((t) => TransactionCard(transaction: t)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADMIN DRAWER (menu samping admin)
// Menu admin memang lebih banyak karena admin mengelola semua data.
// ============================================================

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  // Satu baris menu yang membuka halaman tertentu.
  // Drawer ditutup dulu (pop) lalu halaman dibuka (push), supaya drawer tidak tertinggal terbuka.
  Widget item(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        final nav = Navigator.of(context);
        nav.pop();
        nav.push(MaterialPageRoute(builder: (context) => page));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header drawer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 25),
              color: primaryGreen,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.account_balance_wallet, color: primaryGreen, size: 30),
                  ),
                  SizedBox(height: 14),
                  Text('KosFinance', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 3),
                  Text('Admin / Pengelola', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              ),
            ),
            item(context, Icons.meeting_room_outlined, 'Kamar & Penghuni', const AdminRoomPage()),
            item(context, Icons.people_alt_outlined, 'Akun Terdaftar', const RegisteredUsersPage()),
            // Pengingat jatuh tempo sudah digabung ke menu Iuran
            item(context, Icons.notifications_none, 'Iuran & Reminder', const IuranPage()),
            // Pemasukan & pengeluaran (listrik, wifi, penjaga, dll.)
            item(context, Icons.receipt_long_outlined, 'Transaksi', const TransactionPage()),
            item(context, Icons.bar_chart_outlined, 'Laporan Keuangan', const ReportPage()),
            // Admin bisa EDIT tipe kamar & harga di sini
            item(context, Icons.local_offer_outlined, 'Kamar & Harga (Edit)', const RoomListPage(isAdmin: true)),
            item(context, Icons.build_outlined, 'Laporan Kerusakan', const ComplaintsPage(isAdmin: true)),
            item(context, Icons.campaign_outlined, 'Pengumuman & Peraturan', const AnnouncementsPage(isAdmin: true)),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              // pushAndRemoveUntil: hapus semua halaman sebelumnya, kembali ke login
              onTap: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADMIN: DAFTAR AKUN PENGHUNI / CALON PENGHUNI
// ============================================================

class RegisteredUsersPage extends StatelessWidget {
  const RegisteredUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Semua akun non-admin, diurutkan berdasarkan nama
    final users = accounts.where((account) => account.role != 'Admin').toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: const Text('Akun Terdaftar')),
      body: users.isEmpty
          ? const EmptyState(icon: Icons.people_outline, message: 'Belum ada akun penghuni.')
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final room = roomOf(user);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase())),
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Username: ${user.username}\nNo. HP: ${user.phone}\n${room == null ? 'Belum booking kamar' : 'Kamar ${room.number} • ${room.status}'}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.person_outline),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================
// ADMIN: KAMAR & PENGHUNI (cek kosong, penghuni, sisa hari)
// ============================================================

class AdminRoomPage extends StatefulWidget {
  const AdminRoomPage({super.key});

  @override
  State<AdminRoomPage> createState() => _AdminRoomPageState();
}

class _AdminRoomPageState extends State<AdminRoomPage> {
  String filter = 'Semua'; // filter status kamar

  // Mengisi kamar untuk tamu yang datang langsung (walk-in)
  Future<void> walkIn(Room room) async {
    final nameC = TextEditingController();
    final monthsC = TextEditingController(text: '1');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Isi Kamar ${room.number} (Datang Langsung)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            field(nameC, 'Nama Penghuni', Icons.person_outline),
            field(monthsC, 'Durasi (bulan)', Icons.timelapse_outlined, type: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );

    final name = nameC.text.trim();
    final months = int.tryParse(monthsC.text) ?? 0;
    if (ok != true) return;
    if (name.isEmpty || months <= 0) {
      if (mounted) showMessage(context, 'Nama dan durasi wajib diisi dengan benar.');
      return;
    }

    setState(() {
      // Walk-in juga harus bayar lunas dulu; admin tekan "Tandai Dibayar" di menu Iuran.
      room.status = 'Dipesan';
      room.residentName = name;
      room.checkIn = today;
      room.checkOut = addMonths(today, months);
      createIuran(room, name, today, months: months, booking: true);
      notifyDataChanged();
    });
    if (mounted) {
      showMessage(context, 'Kamar ${room.number} dipesan. Jadi "Terisi" setelah pembayaran lunas dikonfirmasi di Iuran & Reminder.');
    }
  }

  @override
  Widget build(BuildContext context) {
    expireBookingReservations(notify: false);
    // Filter + urutan (kamar "Dipesan" ditaruh paling atas)
    final data = (filter == 'Semua' ? List<Room>.from(rooms) : rooms.where((r) => r.status == filter).toList())
      ..sort((a, b) {
        final aPriority = a.status == 'Dipesan' ? 0 : 1;
        final bPriority = b.status == 'Dipesan' ? 0 : 1;
        if (aPriority != bPriority) return aPriority.compareTo(bPriority);
        return (b.checkIn ?? DateTime(2000)).compareTo(a.checkIn ?? DateTime(2000));
      });
    final terisi = rooms.where((r) => r.status == 'Terisi').length;
    final dipesan = rooms.where((r) => r.status == 'Dipesan').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Kamar & Penghuni')),
      body: Column(
        children: [
          // Statistik singkat kamar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Expanded(child: MiniStat(label: 'Kosong', value: '${vacantCount()}', color: Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: MiniStat(label: 'Dipesan', value: '$dipesan', color: Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: MiniStat(label: 'Terisi', value: '$terisi', color: Colors.blueGrey)),
              ],
            ),
          ),
          // Filter status kamar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: DropdownButtonFormField<String>(
              initialValue: filter,
              decoration: const InputDecoration(labelText: 'Filter Status Kamar'),
              items: const ['Semua', 'Kosong', 'Dipesan', 'Terisi']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => filter = v!),
            ),
          ),
          // Daftar kamar
          Expanded(
            child: data.isEmpty
                ? const EmptyState(icon: Icons.meeting_room_outlined, message: 'Tidak ada kamar.')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: data.length,
                    itemBuilder: (context, i) {
                      final room = data[i];
                      final List<Widget> actions = []; // tombol aksi tergantung status kamar

                      if (room.status == 'Kosong') {
                        // Kamar kosong -> admin bisa isi untuk tamu walk-in
                        actions.add(ElevatedButton.icon(
                          onPressed: () => walkIn(room),
                          icon: const Icon(Icons.person_add_alt),
                          label: const Text('Isi (Walk-in)'),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
                        ));
                      } else if (room.status == 'Dipesan') {
                        // Tidak ada tombol Check-in manual: kamar aktif otomatis setelah booking lunas.
                        actions.add(const Pill(text: 'Menunggu pembayaran lunas', color: Colors.orange));
                        actions.add(OutlinedButton(
                          onPressed: () async {
                            final ok = await confirmAction(context, 'Batalkan booking?', 'Booking ${room.residentName} dibatalkan dan tagihannya dihapus.');
                            if (!ok) return;
                            setState(() {
                              iuranList.removeWhere((b) =>
                                  b.isBooking &&
                                  b.roomNumber == room.number &&
                                  b.residentName == room.residentName &&
                                  b.status != stLunas);
                              room.clear();
                              notifyDataChanged();
                            });
                          },
                          child: const Text('Batalkan'),
                        ));
                      } else {
                        // Kamar terisi -> perpanjang / kosongkan
                        actions.add(OutlinedButton.icon(
                          onPressed: () {
                            // Tidak boleh perpanjang jika masih ada tagihan yang belum lunas
                            final outstanding = iuranList.any((b) => b.residentName == room.residentName && b.status != stLunas);
                            if (outstanding) {
                              showMessage(context, 'Perpanjangan belum bisa dilakukan karena masih ada tagihan yang belum lunas.');
                              return;
                            }
                            setState(() {
                              // Masa sewa baru bertambah setelah tagihan perpanjangan lunas.
                              createIuran(room, room.residentName!, today.add(const Duration(days: 3)), extend: 1);
                              notifyDataChanged();
                            });
                            showMessage(context, 'Tagihan perpanjangan dibuat. Masa sewa bertambah setelah lunas.');
                          },
                          icon: const Icon(Icons.update),
                          label: const Text('Perpanjang 1 bln'),
                        ));
                        actions.add(OutlinedButton(
                          onPressed: () async {
                            final outstanding = iuranList.any((b) => b.residentName == room.residentName && b.status != stLunas);
                            if (outstanding) {
                              showMessage(context, 'Penghuni masih memiliki tagihan. Selesaikan pembayaran sebelum kamar dikosongkan.');
                              return;
                            }
                            final ok = await confirmAction(context, 'Kosongkan kamar?', 'Kontrak ${room.residentName} akan diakhiri.');
                            if (ok) setState(() { room.clear(); notifyDataChanged(); });
                          },
                          child: const Text('Kosongkan', style: TextStyle(color: Colors.red)),
                        ));
                      }

                      return RoomCard(room: room, showResident: true, actions: actions);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DAFTAR TRANSAKSI (admin)
// - Pemasukan iuran tercatat otomatis dari menu Iuran.
// - Bagian "Pengeluaran Rutin" = checklist biaya bulanan pemilik (listrik, air, wifi, penjaga).
// - Tombol + dipakai untuk mencatat pengeluaran lain (lampu, perbaikan, dll).
// ============================================================

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  String filter = 'Semua';

  // Membuka form tambah transaksi (bisa dengan kategori yang sudah terpilih) lalu segarkan halaman
  Future<void> _openForm({String type = 'Pengeluaran', String? category}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTransactionPage(type: type, category: category)),
    );
    if (mounted) setState(() {});
  }

  // Checklist pengeluaran rutin bulan ini: centang hijau jika sudah dicatat, tombol "Catat" jika belum
  Widget _routineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengeluaran Rutin • ${monthLabel(today)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            const Text('Biaya bulanan yang dibayar pemilik kos. Catat agar tidak terlewat.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            ...routineExpenseCategories.map((cat) {
              // Sudah dicatat jika ada transaksi pengeluaran kategori ini di bulan berjalan
              final done = transactions.any((t) => t.type == 'Pengeluaran' && t.category == cat && transactionInMonth(t, today));
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : Colors.grey),
                title: Text(cat),
                trailing: done
                    ? const Pill(text: 'Sudah dicatat', color: Colors.green)
                    : TextButton(onPressed: () => _openForm(category: cat), child: const Text('Catat')),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Kartu satu transaksi lengkap dengan tombol edit & hapus
  Widget _transactionCard(TransactionData transaction) {
    final isIncome = transaction.type == 'Pemasukan';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isIncome ? lightGreen : Colors.red.shade50,
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
          title: Text(transaction.description, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('${transaction.date}\n${transaction.category} • ${transaction.type}'),
          ),
          isThreeLine: true,
          trailing: SizedBox(
            width: 90,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupiah(transaction.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIncome ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Tombol edit
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.edit_outlined, size: 19),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddTransactionPage(transaction: transaction),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    // Tombol hapus
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline, size: 19, color: Colors.red),
                      onPressed: () async {
                        final ok = await confirmAction(context, 'Hapus transaksi?', 'Transaksi ini akan dihapus dan tidak dapat dikembalikan.');
                        if (!ok) return;
                        setState(() {
                          transactions.removeWhere((item) => item.id == transaction.id);
                          notifyDataChanged();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter + urut dari yang terbaru
    final List<TransactionData> data = (filter == 'Semua'
        ? List<TransactionData>.from(transactions)
        : transactions.where((item) => item.type == filter).toList())
      ..sort((a, b) => b.id.compareTo(a.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Transaksi')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Filter jenis transaksi
          DropdownButtonFormField<String>(
            initialValue: filter,
            decoration: const InputDecoration(labelText: 'Filter Transaksi'),
            items: const [
              DropdownMenuItem(value: 'Semua', child: Text('Semua Transaksi')),
              DropdownMenuItem(value: 'Pemasukan', child: Text('Pemasukan')),
              DropdownMenuItem(value: 'Pengeluaran', child: Text('Pengeluaran')),
            ],
            onChanged: (value) => setState(() => filter = value!),
          ),
          const SizedBox(height: 8),
          // Checklist pengeluaran rutin bulan ini
          _routineCard(),
          // Info cara kerja pencatatan
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Pembayaran penghuni (termasuk tunai) tercatat otomatis lewat menu Iuran & Reminder. '
              'Gunakan tombol + untuk pengeluaran lain (lampu, perbaikan, dll) atau pemasukan ganti rugi dari penghuni.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          // Daftar transaksi
          if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: EmptyState(icon: Icons.receipt_long, message: 'Belum ada transaksi.'),
            )
          else
            ...data.map(_transactionCard),
        ],
      ),
      // Tombol + : catat transaksi baru (default pengeluaran)
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================
// TAMBAH / EDIT TRANSAKSI (kategori berupa pilihan)
// - transaction != null -> mode EDIT
// - type / category     -> nilai awal saat tambah baru
// ============================================================

class AddTransactionPage extends StatefulWidget {
  final TransactionData? transaction;
  final String? type;
  final String? category;

  const AddTransactionPage({super.key, this.transaction, this.type, this.category});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  late TextEditingController dateController;
  late TextEditingController descriptionController;
  late TextEditingController amountController;
  late String selectedType;
  late String selectedCategory;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    // Jika edit, isi form dengan data lama; jika baru, pakai nilai default
    dateController = TextEditingController(text: t?.date ?? formatDate(today));
    descriptionController = TextEditingController(text: t?.description ?? widget.category ?? '');
    amountController = TextEditingController(text: t != null ? t.amount.toStringAsFixed(0) : '');
    selectedType = t?.type ?? widget.type ?? 'Pemasukan';
    selectedCategory = t?.category ?? widget.category ?? categoriesFor(selectedType).first;
  }

  // Memilih tanggal transaksi
  Future<void> pickTransactionDate() async {
    final current = parseDate(dateController.text) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => dateController.text = formatDate(picked));
  }

  // Validasi lalu simpan transaksi (baru / hasil edit)
  void saveTransaction() {
    final amount = double.tryParse(amountController.text) ?? 0;

    if (descriptionController.text.trim().isEmpty || amount <= 0) {
      showMessage(context, 'Lengkapi data transaksi terlebih dahulu.');
      return;
    }

    if (widget.transaction != null) {
      // Mode edit: ubah data transaksi yang sudah ada
      widget.transaction!.date = dateController.text.trim();
      widget.transaction!.description = descriptionController.text.trim();
      widget.transaction!.category = selectedCategory;
      widget.transaction!.type = selectedType;
      widget.transaction!.amount = amount;
    } else {
      // Mode tambah: buat transaksi baru
      transactions.add(TransactionData(
        id: DateTime.now().millisecondsSinceEpoch,
        date: dateController.text.trim(),
        description: descriptionController.text.trim(),
        category: selectedCategory,
        type: selectedType,
        amount: amount,
      ));
    }

    notifyDataChanged();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null;
    final cats = categoriesFor(selectedType, selectedCategory);

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Transaksi' : 'Tambah Transaksi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tanggal
          InkWell(
            onTap: pickTransactionDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Tanggal', prefixIcon: Icon(Icons.calendar_today_outlined)),
              child: Text(dateController.text),
            ),
          ),
          const SizedBox(height: 14),
          // Jenis transaksi
          DropdownButtonFormField<String>(
            initialValue: selectedType,
            decoration: const InputDecoration(
              labelText: 'Jenis Transaksi',
              prefixIcon: Icon(Icons.swap_vert_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'Pemasukan', child: Text('Pemasukan')),
              DropdownMenuItem(value: 'Pengeluaran', child: Text('Pengeluaran')),
            ],
            onChanged: (value) => setState(() {
              selectedType = value!;
              // Jika kategori lama tidak cocok dengan jenis baru, ganti ke kategori pertama
              if (!categoriesFor(selectedType).contains(selectedCategory)) {
                selectedCategory = categoriesFor(selectedType).first;
              }
            }),
          ),
          const SizedBox(height: 14),
          field(descriptionController, 'Deskripsi (contoh: Listrik bulan Oktober)', Icons.description_outlined),
          // Kategori berupa pilihan (daftar berubah sesuai jenis transaksi)
          DropdownButtonFormField<String>(
            key: ValueKey('$selectedType-$selectedCategory'),
            initialValue: selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (value) => setState(() => selectedCategory = value!),
          ),
          const SizedBox(height: 14),
          // Nominal
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: saveTransaction,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: Text(isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// IURAN & REMINDER (admin)
// Sudah menggabungkan fitur "Pengingat Jatuh Tempo":
// ringkasan terlambat, keterangan jatuh tempo per tagihan, dan kirim reminder.
// ============================================================

class IuranPage extends StatefulWidget {
  const IuranPage({super.key});

  @override
  State<IuranPage> createState() => _IuranPageState();
}

class _IuranPageState extends State<IuranPage> {
  String filter = 'Semua';

  // Kirim reminder ke semua tagihan yang belum dibayar
  Future<void> remindAll() async {
    final targets = iuranList.where((i) => i.status == stBelum).toList();
    if (targets.isEmpty) {
      showMessage(context, 'Tidak ada tagihan yang perlu diingatkan.');
      return;
    }
    final ok = await confirmAction(context, 'Kirim reminder?', 'Reminder dikirim ke ${targets.length} tagihan yang belum dibayar.');
    if (!ok) return;
    for (final i in targets) {
      addResidentNotification(
        residentName: i.residentName,
        title: 'Pengingat pembayaran',
        message: '${i.iuranType} ${formatRupiah(i.amount)} jatuh tempo ${i.dueDate}. Mohon segera dibayar.',
      );
    }
    if (mounted) showMessage(context, 'Reminder dikirim ke ${targets.length} penghuni.');
  }

  // Tombol aksi di tiap kartu sesuai status pembayaran
  Widget statusActions(IuranData iuran) {
    // Menunggu konfirmasi -> admin periksa bukti
    if (iuran.status == stProses) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProofReviewPage(iuran: iuran)),
            );
            setState(() {});
          },
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Periksa Bukti Pembayaran'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
        ),
      );
    }

    // Belum dibayar -> kirim reminder atau tandai dibayar (bayar langsung/tunai)
    if (iuran.status == stBelum) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                addResidentNotification(
                  residentName: iuran.residentName,
                  title: 'Pengingat pembayaran',
                  message: '${iuran.iuranType} ${formatRupiah(iuran.amount)} jatuh tempo ${iuran.dueDate}. Mohon segera dibayar.',
                );
                showMessage(context, 'Reminder dikirim ke ${iuran.residentName}.');
              },
              icon: const Icon(Icons.notifications_none),
              label: const Text('Reminder'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() {
                iuran.paymentMethod = 'Tunai / Langsung';
                markPaid(iuran);
              }),
              child: const Text('Tandai Dibayar'),
            ),
          ),
        ],
      );
    }

    // Sudah lunas -> bisa dibatalkan
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () async {
          final ok = await confirmAction(context, 'Batalkan pembayaran?', 'Pemasukan yang terkait iuran ini juga akan dibatalkan.');
          if (ok) setState(() => markUnpaid(iuran));
        },
        child: const Text('Tandai Belum Dibayar'),
      ),
    );
  }

  // Kartu satu tagihan
  Widget iuranCard(IuranData iuran) {
    final overdue = isOverdue(iuran);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor(iuran.status).withValues(alpha: 0.12),
                  child: Icon(Icons.person_outline, color: statusColor(iuran.status)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(iuran.residentName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Kamar ${iuran.roomNumber}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                StatusChip(status: iuran.status),
              ],
            ),
            const Divider(height: 24),
            InfoRow(label: 'Jenis Iuran', value: iuran.iuranType),
            InfoRow(label: 'Nominal', value: formatRupiah(iuran.amount)),
            InfoRow(label: 'Jatuh Tempo', value: iuran.dueDate),
            // Keterangan jatuh tempo (fungsi pengingat), merah jika terlambat
            if (iuran.status != stLunas)
              InfoRow(label: 'Keterangan', value: dueLabel(iuran), valueColor: overdue ? Colors.red : null),
            if (iuran.paymentMethod != null)
              InfoRow(label: 'Metode Bayar', value: iuran.paymentMethod!),
            if (iuran.paidAt != null)
              InfoRow(label: 'Tanggal Dibayar', value: formatDate(iuran.paidAt!)),
            if (iuran.proofBytes != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: InteractiveViewer(
                          child: Image.memory(iuran.proofBytes!, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Lihat Bukti Pembayaran'),
                ),
              ),
            const SizedBox(height: 8),
            statusActions(iuran),
            // Edit & hapus tagihan
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => IuranFormPage(iuran: iuran)),
                    );
                    setState(() {});
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Hapus',
                  onPressed: () async {
                    final ok = await confirmAction(context, 'Hapus iuran?', 'Data iuran ${iuran.residentName} akan dihapus.');
                    if (!ok) return;
                    setState(() { iuranList.remove(iuran); notifyDataChanged(); });
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    expireBookingReservations(notify: false);

    // Hitungan ringkasan di bagian atas
    final belum = iuranList.where((i) => i.status == stBelum).length;
    final proses = iuranList.where((i) => i.status == stProses).length;
    final terlambat = iuranList.where(isOverdue).length;

    // Filter + urutan (menunggu konfirmasi & terlambat paling atas)
    final data = (filter == 'Semua' ? List<IuranData>.from(iuranList) : iuranList.where((i) => i.status == filter).toList())
      ..sort((a, b) {
        int p(IuranData x) => x.status == stProses ? 0 : (isOverdue(x) ? 1 : 2);
        if (p(a) != p(b)) return p(a).compareTo(p(b));
        return b.id.compareTo(a.id);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Iuran & Reminder')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Ringkasan status tagihan
          Row(
            children: [
              Expanded(child: MiniStat(label: 'Belum Bayar', value: '$belum', color: Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: MiniStat(label: 'Konfirmasi', value: '$proses', color: Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: MiniStat(label: 'Terlambat', value: '$terlambat', color: Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          // Filter status
          DropdownButtonFormField<String>(
            initialValue: filter,
            decoration: const InputDecoration(labelText: 'Filter Status'),
            items: const ['Semua', stBelum, stProses, stLunas]
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => filter = v!),
          ),
          const SizedBox(height: 8),
          // Reminder massal
          OutlinedButton.icon(
            onPressed: remindAll,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Kirim reminder ke semua yang belum bayar'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Penghuni yang datang membayar langsung: tekan "Tandai Dibayar", otomatis tercatat sebagai pemasukan.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(icon: Icons.people_outline, message: 'Tidak ada data iuran.'),
            )
          else
            ...data.map(iuranCard),
        ],
      ),
      // Tambah tagihan manual
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const IuranFormPage()),
          );
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================
// FORM TAMBAH / EDIT IURAN
// ============================================================

class IuranFormPage extends StatefulWidget {
  final IuranData? iuran; // null = tambah baru, ada isi = edit

  const IuranFormPage({super.key, this.iuran});

  @override
  State<IuranFormPage> createState() => _IuranFormPageState();
}

class _IuranFormPageState extends State<IuranFormPage> {
  late TextEditingController nameController;
  late TextEditingController roomController;
  late TextEditingController typeController;
  late TextEditingController amountController;
  late TextEditingController dueDateController;
  String status = stBelum;

  @override
  void initState() {
    super.initState();
    final iuran = widget.iuran;
    nameController = TextEditingController(text: iuran?.residentName ?? '');
    roomController = TextEditingController(text: iuran?.roomNumber ?? '');
    typeController = TextEditingController(text: iuran?.iuranType ?? 'Iuran Bulanan');
    amountController = TextEditingController(text: iuran != null ? iuran.amount.toStringAsFixed(0) : '');
    dueDateController = TextEditingController(text: iuran?.dueDate ?? formatDate(today));
    status = iuran?.status ?? stBelum;
  }

  // Validasi lalu simpan iuran
  void saveIuran() {
    final amount = double.tryParse(amountController.text) ?? 0;

    if (nameController.text.trim().isEmpty || roomController.text.trim().isEmpty || amount <= 0) {
      showMessage(context, 'Lengkapi data iuran terlebih dahulu.');
      return;
    }

    final old = widget.iuran?.status; // status sebelum diedit
    // Jika tambah baru, buat objek kosong dulu lalu diisi di bawah
    final item = widget.iuran ??
        IuranData(
          id: DateTime.now().millisecondsSinceEpoch,
          residentName: '',
          roomNumber: '',
          iuranType: '',
          amount: 0,
          dueDate: '',
          status: stBelum,
        );

    item.residentName = nameController.text.trim();
    item.roomNumber = roomController.text.trim();
    item.iuranType = typeController.text.trim();
    item.amount = amount;
    item.dueDate = dueDateController.text.trim();
    if (widget.iuran == null) iuranList.add(item);

    if (status == stLunas) {
      item.status = old ?? stBelum;
      markPaid(item); // sekaligus mengaktifkan kamar kalau ini tagihan booking
    } else if (old == stLunas) {
      markUnpaid(item); // dibatalkan: pemasukan terkait ikut dihapus
      item.status = status;
    } else {
      item.status = status;
    }
    notifyDataChanged();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.iuran == null ? 'Tambah Iuran' : 'Edit Iuran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(nameController, 'Nama Penghuni', Icons.person_outline),
          field(roomController, 'Nomor Kamar', Icons.home_outlined),
          field(typeController, 'Jenis Iuran', Icons.category_outlined),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 14),
          field(dueDateController, 'Tanggal Jatuh Tempo (dd/MM/yyyy)', Icons.calendar_today_outlined),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(
              labelText: 'Status Pembayaran',
              prefixIcon: Icon(Icons.check_circle_outline),
            ),
            items: const [stBelum, stProses, stLunas]
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (value) => setState(() => status = value!),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: saveIuran,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: const Text('SIMPAN'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// GRAFIK TREN BULANAN
// Grafik batang vertikal untuk membandingkan pemasukan dan pengeluaran per bulan.
// ============================================================

class MonthlyTrendChart extends StatelessWidget {
  final List<DateTime> months; // daftar bulan yang ditampilkan (urut lama -> baru)
  final String Function(DateTime) monthLabel; // fungsi pembuat nama bulan

  const MonthlyTrendChart({super.key, required this.months, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    // Hitung total pemasukan & pengeluaran tiap bulan
    final data = months.map((month) {
      final items = transactions.where((t) => transactionInMonth(t, month));
      return <String, Object>{
        'month': month,
        'income': items.where((t) => t.type == 'Pemasukan').fold<double>(0.0, (sum, t) => sum + t.amount),
        'expense': items.where((t) => t.type == 'Pengeluaran').fold<double>(0.0, (sum, t) => sum + t.amount),
      };
    }).toList();
    // Nilai terbesar dipakai untuk skala tinggi batang
    double maxAmount = 0;
    for (final row in data) {
      final income = row['income'] as double;
      final expense = row['expense'] as double;
      if (income > maxAmount) maxAmount = income;
      if (expense > maxAmount) maxAmount = expense;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Legenda warna
          Row(children: [
            Container(width: 11, height: 11, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            const SizedBox(width: 5), const Text('Pemasukan', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 14),
            Container(width: 11, height: 11, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            const SizedBox(width: 5), const Text('Pengeluaran', style: TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 18),
          // Batang tiap bulan
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: data.map((row) {
                final month = row['month'] as DateTime;
                final income = row['income'] as double;
                final expense = row['expense'] as double;
                final availableHeight = 154.0; // tinggi maksimum batang
                // Tinggi batang = persentase terhadap nilai terbesar
                final incomeHeight = maxAmount == 0 ? 0.0 : (income / maxAmount * availableHeight).clamp(0.0, availableHeight).toDouble();
                final expenseHeight = maxAmount == 0 ? 0.0 : (expense / maxAmount * availableHeight).clamp(0.0, availableHeight).toDouble();
                final label = monthLabel(month).split(' ').first.substring(0, 3); // 3 huruf pertama nama bulan
                return Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    SizedBox(height: 18, child: FittedBox(fit: BoxFit.scaleDown, child: Text(income >= 1000000 ? '${(income / 1000000).toStringAsFixed(1)} jt' : '${(income / 1000).round()} rb', style: const TextStyle(fontSize: 9, color: Colors.green)))),
                    const SizedBox(height: 3),
                    SizedBox(height: availableHeight, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Tooltip(message: 'Pemasukan $label: ${formatRupiah(income)}', child: Container(width: 12, height: incomeHeight, decoration: const BoxDecoration(color: Colors.green, borderRadius: BorderRadius.vertical(top: Radius.circular(4))))),
                      const SizedBox(width: 3),
                      Tooltip(message: 'Pengeluaran $label: ${formatRupiah(expense)}', child: Container(width: 12, height: expenseHeight, decoration: const BoxDecoration(color: Colors.red, borderRadius: BorderRadius.vertical(top: Radius.circular(4))))),
                    ])),
                    const SizedBox(height: 7),
                    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ));
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Arahkan kursor ke batang untuk melihat nominal lengkap.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}

// ============================================================
// KARTU PENGELUARAN PER KATEGORI
// Menjawab pertanyaan admin: "pengeluaran bulan ini berapa, dan untuk apa saja?"
// Dipakai di Dashboard Admin dan Laporan Keuangan.
// ============================================================

class ExpenseBreakdownCard extends StatelessWidget {
  final DateTime month; // bulan yang dirinci

  const ExpenseBreakdownCard({super.key, required this.month});

  @override
  Widget build(BuildContext context) {
    final items = expenseBreakdown(month); // sudah terurut dari terbesar
    final total = items.fold<double>(0.0, (sum, e) => sum + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengeluaran per Kategori • ${monthLabel(month)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Total ${formatRupiah(total)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text('Belum ada pengeluaran pada bulan ini.', style: TextStyle(color: Colors.grey))
            else
              ...items.map((e) {
                final percent = total == 0 ? 0.0 : e.value / total; // porsi terhadap total
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(expenseIcon(e.key), size: 20, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text('${formatRupiah(e.value)} (${(percent * 100).round()}%)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                          color: Colors.red,
                          backgroundColor: Colors.red.withValues(alpha: 0.10),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LAPORAN KEUANGAN
// ============================================================

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late DateTime selectedMonth; // bulan laporan yang dipilih

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime(today.year, today.month);
    appDataRevision.addListener(_refreshData);
  }

  void _refreshData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_refreshData);
    super.dispose();
  }

  // Transaksi pada bulan yang dipilih
  List<TransactionData> get monthTransactions =>
      transactions.where((t) => transactionInMonth(t, selectedMonth)).toList();

  double get totalIncome => monthTransactions
      .where((t) => t.type == 'Pemasukan')
      .fold<double>(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => monthTransactions
      .where((t) => t.type == 'Pengeluaran')
      .fold<double>(0.0, (sum, t) => sum + t.amount);

  @override
  Widget build(BuildContext context) {
    final balance = totalIncome - totalExpense;
    final maxAmount = totalIncome > totalExpense ? totalIncome : totalExpense;
    // 6 bulan terakhir (termasuk bulan ini)
    final months = List.generate(6, (index) => DateTime(today.year, today.month - index));

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Keuangan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Ringkasan Keuangan', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Laporan dihitung dari transaksi yang tercatat, bukan dari tagihan yang belum dibayar.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 14),
          // Pilih periode laporan
          DropdownButtonFormField<DateTime>(
            initialValue: selectedMonth,
            decoration: const InputDecoration(labelText: 'Periode laporan', prefixIcon: Icon(Icons.calendar_month_outlined)),
            items: months.map((m) => DropdownMenuItem(value: m, child: Text(monthLabel(m)))).toList(),
            onChanged: (value) { if (value != null) setState(() => selectedMonth = value); },
          ),
          const SizedBox(height: 16),
          SummaryCard(title: 'Pemasukan', value: formatRupiah(totalIncome), icon: Icons.trending_up, color: Colors.green),
          SummaryCard(title: 'Pengeluaran', value: formatRupiah(totalExpense), icon: Icons.trending_down, color: Colors.red),
          SummaryCard(title: 'Saldo Bersih', value: formatRupiah(balance), icon: Icons.account_balance_wallet, color: Colors.blue),
          const SizedBox(height: 18),
          Text('Pemasukan vs Pengeluaran • ${monthLabel(selectedMonth)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          FinancialBar(title: 'Pemasukan', amount: totalIncome, maxAmount: maxAmount, color: Colors.green),
          FinancialBar(title: 'Pengeluaran', amount: totalExpense, maxAmount: maxAmount, color: Colors.red),
          const SizedBox(height: 22),
          // Tren 6 bulan
          const Text('Tren 6 Bulan Terakhir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Batang vertikal membandingkan pemasukan dan pengeluaran setiap bulan.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          MonthlyTrendChart(months: months.reversed.toList(), monthLabel: monthLabel),
          const SizedBox(height: 18),
          // Rincian pengeluaran per kategori pada bulan yang dipilih
          ExpenseBreakdownCard(month: selectedMonth),
          const SizedBox(height: 14),
          // Kondisi keuangan (positif / negatif)
          Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: balance >= 0 ? lightGreen : Colors.red.shade50, child: Icon(balance >= 0 ? Icons.check_circle_outline : Icons.warning_amber_outlined, color: balance >= 0 ? Colors.green : Colors.red)),
              title: const Text('Kondisi Keuangan', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(balance >= 0 ? 'Saldo periode ini positif.' : 'Saldo periode ini negatif.'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CUSTOMER DASHBOARD (penghuni)
// Dibuat sederhana. Urutan: Notifikasi -> Pengingat (hanya jika ada tagihan)
// -> Pengumuman -> Kamar Saya -> Tagihan Saya -> Lapor Kerusakan
// ============================================================

class CustomerDashboard extends StatefulWidget {
  final UserAccount user; // penghuni yang sedang login

  const CustomerDashboard({super.key, required this.user});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  @override
  void initState() {
    super.initState();
    appDataRevision.addListener(_refresh); // refresh otomatis saat data berubah
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_refresh);
    super.dispose();
  }

  // Buka halaman lain lalu segarkan dashboard saat kembali
  void go(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => setState(() {}));
  }

  // ---------- 1. NOTIFIKASI (paling atas, seperti admin) ----------
  Widget _notificationsSection(List<ResidentNotificationData> all) {
    final latest = all.take(3).toList(); // cukup 3 terbaru supaya tidak ramai
    final unread = all.where((n) => !n.isRead).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.notifications_active_outlined, color: primaryGreen),
              const SizedBox(width: 8),
              const Expanded(child: Text('Notifikasi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              if (unread > 0)
                CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.red,
                  child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
            ]),
            const SizedBox(height: 8),
            if (latest.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Belum ada notifikasi baru.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...latest.map((n) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: n.isRead ? Colors.grey.shade100 : lightGreen,
                      child: Icon(Icons.notifications_none, color: n.isRead ? Colors.grey : primaryGreen),
                    ),
                    title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text('${n.message}\n${formatDateTime(n.createdAt)}'),
                    isThreeLine: true,
                    onTap: () => setState(() => n.isRead = true), // ketuk = tandai dibaca
                  )),
            if (unread > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    for (final n in all) {
                      n.isRead = true;
                    }
                  }),
                  child: const Text('Tandai semua dibaca'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- 2. PENGINGAT JATUH TEMPO (oranye, hanya tampil jika ada tagihan) ----------
  Widget _reminderSection(List<IuranData> pending) {
    return Card(
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.alarm, color: Colors.orange),
              SizedBox(width: 8),
              Text('Pengingat Jatuh Tempo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            ...pending.map((i) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    i.status == stProses ? Icons.hourglass_top : Icons.warning_amber_rounded,
                    color: i.status == stProses ? Colors.blue : Colors.orange,
                  ),
                  title: Text('${i.iuranType} • ${formatRupiah(i.amount)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(dueLabel(i)),
                )),
          ],
        ),
      ),
    );
  }

  // ---------- 3. PENGUMUMAN & PERATURAN (biru) ----------
  Widget _announcementSection() {
    final latest = announcements.take(2).toList();
    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.campaign_outlined, color: Colors.blue),
              const SizedBox(width: 8),
              const Expanded(child: Text('Pengumuman & Peraturan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              TextButton(
                onPressed: () => go(const AnnouncementsPage()),
                child: const Text('Semua'),
              ),
            ]),
            if (latest.isEmpty)
              const Text('Belum ada pengumuman.', style: TextStyle(color: Colors.grey))
            else
              // ExpansionTile: judul bisa diketuk untuk membuka isi pengumuman
              ...latest.map((a) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(formatDate(a.createdAt), style: const TextStyle(fontSize: 12)),
                    childrenPadding: const EdgeInsets.only(bottom: 10),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(a.body)],
                  )),
          ],
        ),
      ),
    );
  }

  // ---------- 4. KAMAR SAYA (hanya INFO kamar & masa sewa, tanpa pembayaran) ----------
  Widget _roomSection(UserAccount user, Room? room) {
    // Belum punya kamar -> ajak cek kamar & harga
    if (room == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Belum memiliki kamar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Lihat tipe, harga, diskon, dan kamar yang masih kosong, lalu booking.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => go(RoomListPage(user: user)),
                  icon: const Icon(Icons.search),
                  label: const Text('Cek Kamar & Harga'),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final type = roomTypes[room.typeIndex];
    final isActive = room.status == 'Terisi';
    final days = room.daysLeft;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kamar ${room.number}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(type.name, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                Pill(
                  text: isActive ? 'Aktif' : 'Belum Aktif',
                  color: isActive ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const Divider(height: 24),
            if (isActive) ...[
              InfoRow(
                label: 'Masa sewa tersisa',
                value: days == null ? '-' : (days < 0 ? 'Sudah berakhir' : '$days hari'),
              ),
              if (room.checkIn != null) InfoRow(label: 'Check-in', value: formatDate(room.checkIn!)),
              if (room.checkOut != null) InfoRow(label: 'Check-out', value: formatDate(room.checkOut!)),
            ] else ...[
              if (room.checkIn != null) InfoRow(label: 'Rencana masuk', value: formatDate(room.checkIn!)),
              const SizedBox(height: 6),
              const Text(
                'Kamar baru aktif setelah pembayaran booking lunas 100% dikonfirmasi pemilik kos. Bayar lewat bagian Tagihan di bawah.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- 5. TAGIHAN SAYA (pembayaran) ----------
  Widget _billSection(IuranData? active) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: active == null
            ? const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Expanded(child: Text('Belum ada tagihan.', style: TextStyle(color: Colors.grey))),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(formatRupiah(active.amount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      StatusChip(status: active.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${active.iuranType} • jatuh tempo ${active.dueDate}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  // Tampilkan alasan jika pembayaran sebelumnya ditolak admin
                  if (active.status == stBelum && active.rejectNote != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('Pembayaran sebelumnya ditolak: ${active.rejectNote}', style: const TextStyle(color: Colors.red)),
                    ),
                  // Tombol/keterangan berbeda sesuai status pembayaran
                  if (active.status == stBelum)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => go(PaymentPage(iuran: active)),
                        icon: const Icon(Icons.payment),
                        label: const Text('Bayar Sekarang (Lunas)'),
                        style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
                      ),
                    )
                  else if (active.status == stProses)
                    const Row(children: [
                      Icon(Icons.hourglass_top, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Pembayaran sedang diperiksa pemilik kos.', style: TextStyle(color: Colors.blue))),
                    ])
                  else
                    const Row(children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Sudah lunas. Terima kasih!', style: TextStyle(color: Colors.green))),
                    ]),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => go(MyIuranPage(user: widget.user)),
                      child: const Text('Semua tagihan & riwayat'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Tombol akses cepat (kartu kecil)
  Widget _quickAction(IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: lightGreen, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: primaryGreen),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bersihkan booking yang lewat 24 jam dan belum dibayar (tanpa notify agar aman di build).
    expireBookingReservations(notify: false);

    final user = widget.user;
    final myIurans = iuranFor(user); // semua tagihan milik penghuni ini
    final pending = myIurans.where((i) => i.status != stLunas).toList(); // yang belum lunas
    // Tagihan yang ditampilkan: yang belum lunas dulu, kalau tidak ada tampilkan yang terakhir
    final IuranData? active = pending.isNotEmpty ? pending.first : (myIurans.isNotEmpty ? myIurans.last : null);

    final room = roomOf(user);
    final isActive = room?.status == 'Terisi';
    final notes = notificationsFor(user);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Penghuni', style: TextStyle(fontWeight: FontWeight.bold))),
      drawer: CustomerDrawer(user: user),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Kartu sapaan
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 30, color: primaryGreen),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Selamat datang,', style: TextStyle(color: Colors.white70)),
                        Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(
                          room == null
                              ? 'Belum memiliki kamar'
                              : isActive
                                  ? 'Kamar ${room.number}'
                                  : 'Kamar ${room.number} • menunggu pembayaran',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _notificationsSection(notes),
            // Kartu pengingat hanya muncul jika ada tagihan yang belum lunas
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 4),
              _reminderSection(pending),
            ],
            const SizedBox(height: 4),
            _announcementSection(),
            const SizedBox(height: 14),
            const Text('Kamar Saya', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _roomSection(user, room),
            const SizedBox(height: 14),
            const Text('Tagihan Saya', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _billSection(active),
            // Tombol lapor kerusakan hanya untuk penghuni yang kamarnya sudah aktif
            if (isActive) ...[
              const SizedBox(height: 14),
              _quickAction(Icons.build_outlined, 'Lapor Kerusakan', () => go(ComplaintsPage(user: user))),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CUSTOMER DRAWER (menu ringkas penghuni)
// Sengaja dibuat sedikit supaya penghuni tidak bingung (arahan dosen).
// ============================================================

class CustomerDrawer extends StatelessWidget {
  final UserAccount user;

  const CustomerDrawer({super.key, required this.user});

  // Satu baris menu: tutup drawer lalu buka halaman tujuan
  Widget item(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        final nav = Navigator.of(context);
        nav.pop();
        nav.push(MaterialPageRoute(builder: (context) => page));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = roomOf(user);
    final isActive = room?.status == 'Terisi';

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header drawer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              color: primaryGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: primaryGreen, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    room == null ? 'Calon Penghuni' : 'Penghuni',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => CustomerDashboard(user: user)),
              ),
            ),
            // Hanya untuk calon penghuni (belum punya kamar / booking)
            if (room == null)
              item(context, Icons.meeting_room_outlined, 'Cek Kamar & Harga', RoomListPage(user: user)),
            item(context, Icons.receipt_long_outlined, 'Iuran & Riwayat', MyIuranPage(user: user)),
            // Hanya untuk penghuni dengan kamar aktif
            if (isActive)
              item(context, Icons.build_outlined, 'Lapor Kerusakan', ComplaintsPage(user: user)),
            item(context, Icons.person_outline, 'Profil Akun', ProfilePage(user: user)),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// IURAN & RIWAYAT (penghuni) - tagihan + riwayat pembayaran jadi satu
// ============================================================

class MyIuranPage extends StatefulWidget {
  final UserAccount user;

  const MyIuranPage({super.key, required this.user});

  @override
  State<MyIuranPage> createState() => _MyIuranPageState();
}

class _MyIuranPageState extends State<MyIuranPage> {
  // Kartu satu tagihan yang belum lunas
  Widget _billCard(IuranData iuran) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Kamar ${iuran.roomNumber}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                StatusChip(status: iuran.status),
              ],
            ),
            const Divider(height: 28),
            InfoRow(label: 'Jenis Iuran', value: iuran.iuranType),
            InfoRow(label: 'Nominal', value: formatRupiah(iuran.amount)),
            InfoRow(label: 'Jatuh Tempo', value: iuran.dueDate),
            if (iuran.bookingDeadline != null && iuran.status == stBelum)
              InfoRow(label: 'Bayar sebelum', value: formatDateTime(iuran.bookingDeadline!)),
            if (iuran.paymentMethod != null) InfoRow(label: 'Metode Bayar', value: iuran.paymentMethod!),
            const SizedBox(height: 12),
            // Indikator 3 tahap pembayaran
            PaymentSteps(status: iuran.status),
            if (iuran.status == stBelum) ...[
              const SizedBox(height: 14),
              if (iuran.rejectNote != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('Pembayaran sebelumnya ditolak: ${iuran.rejectNote}', style: const TextStyle(color: Colors.red)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentPage(iuran: iuran)));
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Bayar Sekarang (Lunas)'),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    expireBookingReservations(notify: false);
    // Semua tagihan penghuni, diurutkan dari yang terbaru
    final all = iuranFor(widget.user)..sort((a, b) => b.id.compareTo(a.id));
    final pending = all.where((i) => i.status != stLunas).toList(); // belum lunas
    final paid = all.where((i) => i.status == stLunas).toList(); // riwayat lunas

    return Scaffold(
      appBar: AppBar(title: const Text('Iuran & Riwayat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tagihan yang harus dibayar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tidak ada tagihan. Semua sudah lunas.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...pending.map(_billCard),
          const SizedBox(height: 18),
          const Text('Riwayat pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (paid.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada pembayaran yang lunas.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...paid.map((i) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.12),
                      child: const Icon(Icons.check, color: Colors.green),
                    ),
                    title: Text('${i.iuranType} • Kamar ${i.roomNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Dibayar ${i.paidAt == null ? '-' : formatDate(i.paidAt!)}${i.paymentMethod != null ? ' • ${i.paymentMethod}' : ''}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatRupiah(i.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        // Link ke kuitansi PDF
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => InvoicePage(user: widget.user, iuran: i)),
                          ),
                          child: const Text('Invoice', style: TextStyle(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

// ============================================================
// PEMBAYARAN (QRIS / Transfer Bank / Hubungi Pemilik)
// ============================================================

class PaymentPage extends StatefulWidget {
  final IuranData iuran; // tagihan yang akan dibayar

  const PaymentPage({super.key, required this.iuran});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String method = 'QRIS'; // metode yang dipilih
  Uint8List? proof; // foto bukti pembayaran
  final senderC = TextEditingController();
  final picker = ImagePicker();

  // Metode selain "Hubungi Pemilik" wajib upload bukti
  bool get needProof => method != 'Hubungi Pemilik';

  // Salin teks ke clipboard
  void copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showMessage(context, 'Disalin: $text');
  }

  // Pilih foto bukti pembayaran dari galeri
  Future<void> pickProof() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => proof = bytes);
  }

  // Panel informasi sesuai metode yang dipilih
  Widget methodPanel() {
    if (method == 'QRIS') {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_2, size: 150, color: Colors.grey),
                SizedBox(height: 8),
                Text('QRIS SIMULASI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'SIMULASI UTS — ikon ini bukan kode QRIS yang dapat dipindai. Untuk pembayaran sungguhan, gunakan QRIS resmi milik pengelola. Unggah bukti pembayaran simulasi di bawah.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    if (method == 'Transfer Bank') {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance, color: primaryGreen),
          title: const Text(bankInfo, style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Transfer sesuai nominal tagihan, lalu unggah bukti transfer.'),
          trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => copy('1234567890')),
        ),
      );
    }

    // Metode "Hubungi Pemilik" (bayar tunai)
    return Card(
      child: ListTile(
        leading: const Icon(Icons.phone_in_talk, color: primaryGreen),
        title: const Text(ownerPhone, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Hubungi pemilik kos via telepon/WhatsApp untuk bayar tunai. Pemilik akan mengonfirmasi setelah uang diterima.'),
        trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => copy(ownerPhone)),
      ),
    );
  }

  // Bagian upload bukti pembayaran
  Widget proofSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bukti Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        field(senderC, 'Nama pengirim / pemilik rekening', Icons.person_outline),
        if (proof != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(proof!, height: 220, width: double.infinity, fit: BoxFit.cover),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: pickProof,
          icon: const Icon(Icons.upload_file),
          label: Text(proof == null ? 'Unggah Foto Bukti' : 'Ganti Foto Bukti'),
        ),
      ],
    );
  }

  // Kirim pembayaran -> status jadi "Menunggu Konfirmasi"
  void submit() {
    final i = widget.iuran;

    // Cegah pengiriman ganda / pembayaran yang tidak valid
    if (i.status == stProses) {
      showMessage(context, 'Pembayaran ini sedang menunggu konfirmasi pemilik kos.');
      return;
    }

    if (i.status == stLunas) {
      showMessage(context, 'Tagihan ini sudah dikonfirmasi lunas.');
      return;
    }

    if (i.bookingDeadline != null &&
        DateTime.now().isAfter(i.bookingDeadline!) &&
        i.status != stLunas) {
      showMessage(context, 'Batas pembayaran booking sudah berakhir. Silakan lakukan booking ulang.');
      return;
    }

    // Validasi bukti (kecuali bayar tunai)
    if (needProof) {
      if (proof == null) {
        showMessage(context, 'Unggah foto bukti pembayaran terlebih dahulu.');
        return;
      }
      if (senderC.text.trim().isEmpty) {
        showMessage(context, 'Isi nama pengirim / pemilik rekening.');
        return;
      }
    }

    // Simpan data pembayaran ke tagihan
    i.status = stProses;
    i.paymentMethod = method == 'Hubungi Pemilik' ? 'Tunai (via telepon)' : method;
    i.proofBytes = needProof ? proof : null;
    i.proofSender = needProof ? senderC.text.trim() : null;
    i.rejectNote = null;

    // Semua halaman yang sedang terbuka (termasuk Dashboard Penghuni)
    // langsung mengetahui bahwa status pembayaran berubah.
    notifyDataChanged();

    // Beri tahu admin ada bukti pembayaran baru
    addAdminNotification(
      type: 'payment',
      title: 'Bukti pembayaran baru',
      message: '${i.residentName} mengirim pembayaran ${formatRupiah(i.amount)} untuk kamar ${i.roomNumber}.',
    );

    // Beri konfirmasi ke penghuni sendiri
    addResidentNotification(
      residentName: i.residentName,
      title: 'Pembayaran dikirim',
      message: 'Pembayaran ${formatRupiah(i.amount)} untuk ${i.iuranType} sedang menunggu konfirmasi pemilik kos.',
    );

    showMessage(context, 'Terkirim. Menunggu konfirmasi pemilik kos.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final iuran = widget.iuran;

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran Iuran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total tagihan
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Total Tagihan', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    formatRupiah(iuran.amount),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryGreen),
                  ),
                  const SizedBox(height: 4),
                  Text('${iuran.iuranType} • Kamar ${iuran.roomNumber}'),
                  const SizedBox(height: 4),
                  const Text('Pembayaran harus lunas 100% (tidak bisa dicicil).', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Pilih metode pembayaran
          const Text('Pilih Metode Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['QRIS', 'Transfer Bank', 'Hubungi Pemilik']
                .map((m) => ChoiceChip(
                      label: Text(m),
                      selected: method == m,
                      selectedColor: lightGreen,
                      onSelected: (_) => setState(() => method = m),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          methodPanel(),
          if (needProof) ...[
            const SizedBox(height: 14),
            proofSection(),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: submit,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              child: Text(needProof ? 'KIRIM BUKTI PEMBAYARAN' : 'AJUKAN PEMBAYARAN TUNAI'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ADMIN: PERIKSA BUKTI PEMBAYARAN
// ============================================================

class ProofReviewPage extends StatelessWidget {
  final IuranData iuran;

  const ProofReviewPage({super.key, required this.iuran});

  // Tolak pembayaran + beri alasan ke penghuni
  Future<void> reject(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pembayaran'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Alasan (mis. nominal tidak sesuai)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tolak')),
        ],
      ),
    );

    if (ok != true) return;
    // Kembalikan status ke Belum Dibayar dan simpan alasan penolakan
    iuran.status = stBelum;
    iuran.rejectNote = c.text.trim().isEmpty ? 'Bukti pembayaran tidak valid.' : c.text.trim();
    iuran.proofBytes = null;
    iuran.proofSender = null;

    addResidentNotification(
      residentName: iuran.residentName,
      title: 'Pembayaran ditolak',
      message: iuran.rejectNote ?? 'Bukti pembayaran perlu diperbaiki.',
    );

    notifyDataChanged();
    if (context.mounted) Navigator.pop(context);
  }

  // Perbesar foto bukti
  void zoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(child: Image.memory(iuran.proofBytes!)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Periksa Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Detail pembayaran
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InfoRow(label: 'Penghuni', value: iuran.residentName),
                  InfoRow(label: 'Kamar', value: iuran.roomNumber),
                  InfoRow(label: 'Nominal tagihan', value: formatRupiah(iuran.amount)),
                  InfoRow(label: 'Metode', value: iuran.paymentMethod ?? '-'),
                  InfoRow(label: 'Nama pengirim', value: iuran.proofSender ?? '-'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Bukti Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (iuran.proofBytes != null)
            GestureDetector(
              onTap: () => zoom(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(iuran.proofBytes!, width: double.infinity, fit: BoxFit.fitWidth),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'Tidak ada foto bukti (pembayaran tunai via telepon atau data contoh). Konfirmasi hanya jika uang sudah diterima.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Cocokkan nominal, tanggal, dan nama pengirim dengan mutasi rekening / e-wallet sebelum mengonfirmasi.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 18),
          // Tombol tolak / konfirmasi
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => reject(context),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    markPaid(iuran); // tandai lunas + catat pemasukan otomatis
                    showMessage(context, 'Pembayaran ${iuran.residentName} dikonfirmasi.');
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Konfirmasi'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PROFIL AKUN (penghuni)
// ============================================================

class ProfilePage extends StatelessWidget {
  final UserAccount user;

  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final room = roomOf(user);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Akun')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: lightGreen,
            child: Icon(Icons.person, size: 60, color: primaryGreen),
          ),
          const SizedBox(height: 20),
          Center(child: Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          const SizedBox(height: 20),
          ProfileInfoCard(icon: Icons.person_outline, title: 'Nama', value: user.name),
          ProfileInfoCard(icon: Icons.home_outlined, title: 'Nomor Kamar', value: room?.number ?? '-'),
          ProfileInfoCard(icon: Icons.account_circle_outlined, title: 'Username', value: user.username),
          ProfileInfoCard(icon: Icons.phone_outlined, title: 'Nomor Telepon', value: user.phone),
          if (user.email.isNotEmpty)
            ProfileInfoCard(icon: Icons.email_outlined, title: 'Email', value: user.email),
        ],
      ),
    );
  }
}

// ============================================================
// LAPOR KERUSAKAN / KOMPLAIN
// Penghuni: pilih kategori (Air, Listrik, AC, Lampu, Lainnya) + tulis alasan.
// Admin: lihat STATISTIK laporan per kategori per bulan + kelola status laporan.
// ============================================================

class ComplaintsPage extends StatefulWidget {
  final UserAccount? user; // penghuni (null jika admin)
  final bool isAdmin;
  const ComplaintsPage({super.key, this.user, this.isAdmin = false});

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  final descriptionC = TextEditingController();
  Uint8List? photoBytes;
  final picker = ImagePicker();
  String? selectedCategory; // kategori yang dipilih penghuni
  late DateTime selectedMonth; // bulan statistik (admin)

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime(today.year, today.month);
  }

  // Pilih foto kerusakan (opsional)
  Future<void> pickPhoto() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => photoBytes = bytes);
  }

  // Kirim laporan: wajib pilih kategori + isi alasan
  void submitComplaint() {
    final room = widget.user == null ? null : roomOf(widget.user!);
    if (selectedCategory == null) {
      showMessage(context, 'Pilih kategori kerusakan terlebih dahulu.');
      return;
    }
    if (descriptionC.text.trim().isEmpty) {
      showMessage(context, 'Tuliskan alasan / detail kerusakan terlebih dahulu.');
      return;
    }
    if (room == null) {
      showMessage(context, 'Akun ini belum terhubung ke kamar. Hubungi admin untuk demo.');
      return;
    }
    final category = selectedCategory!;
    // insert(0, ...) = laporan terbaru ditaruh paling atas
    complaints.insert(0, ComplaintData(
      id: DateTime.now().millisecondsSinceEpoch,
      residentName: widget.user!.name,
      roomNumber: room.number,
      category: category,
      description: descriptionC.text.trim(),
      createdAt: DateTime.now(),
      photoBytes: photoBytes,
    ));
    // Admin diberi tahu ada laporan baru
    addAdminNotification(
      type: 'complaint',
      title: 'Laporan kerusakan baru ($category)',
      message: '${widget.user!.name} melaporkan masalah $category di kamar ${room.number}.',
    );
    descriptionC.clear();
    setState(() {
      photoBytes = null;
      selectedCategory = null;
    });
    showMessage(context, 'Laporan berhasil dikirim ke pengelola.');
  }

  // ---------- Form laporan (penghuni) ----------
  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ada fasilitas rusak?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Pilih jenis kerusakan, lalu jelaskan masalahnya. Sertakan foto agar pengelola mudah memeriksa.'),
        const SizedBox(height: 14),
        const Text('1. Pilih kategori', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Pilihan kategori berupa chip
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: complaintCategories
              .map((c) => ChoiceChip(
                    avatar: Icon(complaintIcon(c), size: 18, color: selectedCategory == c ? primaryGreen : Colors.grey),
                    label: Text(c),
                    selected: selectedCategory == c,
                    selectedColor: lightGreen,
                    onSelected: (_) => setState(() => selectedCategory = c),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),
        const Text('2. Tulis alasan / detail', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Hint di kolom deskripsi berubah sesuai kategori
        TextField(
          controller: descriptionC,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: selectedCategory == null ? 'Alasan laporan' : 'Alasan laporan ($selectedCategory)',
            hintText: complaintHint(selectedCategory ?? 'Lainnya'),
            alignLabelWithHint: true,
            prefixIcon: const Icon(Icons.edit_note),
          ),
        ),
        const SizedBox(height: 10),
        if (photoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(photoBytes!, height: 180, fit: BoxFit.cover),
          ),
        OutlinedButton.icon(
          onPressed: pickPhoto,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(photoBytes == null ? 'Tambah Foto (opsional)' : 'Ganti Foto'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: submitComplaint,
          icon: const Icon(Icons.send_outlined),
          label: const Text('KIRIM LAPORAN'),
          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
        ),
        const Divider(height: 30),
        const Text('Status Laporan Saya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ---------- Statistik laporan (admin) ----------
  Widget _stats(List<ComplaintData> monthList, List<DateTime> months) {
    // Hitung jumlah laporan per kategori
    final counts = <String, int>{for (final c in complaintCategories) c: 0};
    for (final c in monthList) {
      counts[c.category] = (counts[c.category] ?? 0) + 1;
    }
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b); // skala bar
    final menunggu = monthList.where((c) => c.status == 'Menunggu').length;
    final diproses = monthList.where((c) => c.status == 'Diproses').length;
    final selesai = monthList.where((c) => c.status == 'Selesai').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statistik Laporan Penghuni', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // Pilih bulan statistik (default bulan ini)
            DropdownButtonFormField<DateTime>(
              initialValue: selectedMonth,
              decoration: const InputDecoration(labelText: 'Bulan', prefixIcon: Icon(Icons.calendar_month_outlined)),
              items: months.map((m) => DropdownMenuItem(value: m, child: Text(monthLabel(m)))).toList(),
              onChanged: (v) { if (v != null) setState(() => selectedMonth = v); },
            ),
            const SizedBox(height: 14),
            Text('${monthList.length} laporan pada ${monthLabel(selectedMonth)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            // Bar jumlah laporan per kategori
            ...complaintCategories.map((cat) {
              final n = counts[cat] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(complaintIcon(cat), size: 20, color: primaryGreen),
                    const SizedBox(width: 8),
                    SizedBox(width: 60, child: Text(cat)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: maxCount == 0 ? 0 : n / maxCount,
                          minHeight: 12,
                          color: primaryGreen,
                          backgroundColor: lightGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 24, child: Text('$n', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            // Rekap status penanganan
            Row(
              children: [
                Expanded(child: MiniStat(label: 'Menunggu', value: '$menunggu', color: Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: MiniStat(label: 'Diproses', value: '$diproses', color: Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: MiniStat(label: 'Selesai', value: '$selesai', color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Kartu satu laporan ----------
  Widget _complaintCard(ComplaintData c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isAdmin ? '${c.residentName} • Kamar ${c.roomNumber}' : 'Laporan • Kamar ${c.roomNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Admin bisa ubah status; penghuni hanya melihat (onChanged null = dropdown nonaktif)
                DropdownButton<String>(
                  value: c.status,
                  items: const ['Menunggu', 'Diproses', 'Selesai'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: widget.isAdmin
                      ? (v) {
                          if (v == null) return;
                          setState(() => c.status = v);
                          notifyDataChanged();
                          // Penghuni diberi tahu status laporannya berubah
                          addResidentNotification(
                            residentName: c.residentName,
                            title: 'Status komplain diperbarui',
                            message: 'Laporan ${c.category} kamu sekarang berstatus $v.',
                          );
                        }
                      : null,
                ),
              ],
            ),
            // Kategori laporan
            Pill(text: c.category, color: primaryGreen),
            const SizedBox(height: 8),
            Text(c.description),
            const SizedBox(height: 6),
            Text(formatDate(c.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if (c.photoBytes != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(c.photoBytes!, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final months = List.generate(6, (i) => DateTime(today.year, today.month - i));

    // Admin: laporan pada bulan terpilih. Penghuni: semua laporan miliknya.
    final list = widget.isAdmin
        ? complaints.where((c) => c.createdAt.year == selectedMonth.year && c.createdAt.month == selectedMonth.month).toList()
        : complaints.where((c) => c.residentName == widget.user?.name).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.isAdmin ? 'Laporan Kerusakan' : 'Lapor Kerusakan / Komplain')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.isAdmin) _stats(list, months) else _form(),
          if (widget.isAdmin) ...[
            const SizedBox(height: 8),
            const Text('Daftar Laporan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: EmptyState(icon: Icons.build_outlined, message: 'Belum ada laporan kerusakan.'),
            )
          else
            ...list.map(_complaintCard),
          if (widget.isAdmin)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Status dapat diubah oleh admin. Jika kerusakan akibat kesalahan penghuni, catat uang ganti rugi di menu Transaksi '
                '(Pemasukan • Ganti Rugi Kerusakan). Biaya perbaikannya dicatat sebagai Pengeluaran • Perbaikan Fasilitas.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// PENGUMUMAN DAN PERATURAN KOS
// Admin boleh menerbitkan pengumuman; penghuni hanya membaca.
// ============================================================

class AnnouncementsPage extends StatefulWidget {
  final bool isAdmin;
  const AnnouncementsPage({super.key, this.isAdmin = false});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final titleC = TextEditingController();
  final bodyC = TextEditingController();

  // Terbitkan pengumuman baru (admin)
  void addAnnouncement() {
    if (titleC.text.trim().isEmpty || bodyC.text.trim().isEmpty) {
      showMessage(context, 'Judul dan isi pengumuman wajib diisi.');
      return;
    }
    announcements.insert(0, AnnouncementData(
      id: DateTime.now().millisecondsSinceEpoch,
      title: titleC.text.trim(),
      body: bodyC.text.trim(),
      createdAt: DateTime.now(),
    ));
    titleC.clear();
    bodyC.clear();
    notifyDataChanged();
    setState(() {});
    showMessage(context, 'Pengumuman berhasil ditambahkan.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman & Peraturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Form pengumuman (hanya admin)
          if (widget.isAdmin) ...[
            const Text('Buat pengumuman baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Judul pengumuman')),
            const SizedBox(height: 10),
            TextField(controller: bodyC, maxLines: 3, decoration: const InputDecoration(labelText: 'Isi pengumuman / peraturan')),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: addAnnouncement,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('TERBITKAN'),
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
            ),
            const Divider(height: 30),
          ],
          // Daftar pengumuman
          if (announcements.isEmpty)
            const EmptyState(icon: Icons.campaign_outlined, message: 'Belum ada pengumuman.')
          else
            ...announcements.map((a) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign_outlined, color: primaryGreen),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(a.body),
                    const SizedBox(height: 8),
                    Text(formatDate(a.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }
}

// ============================================================
// INVOICE / KUITANSI PDF
// ============================================================

class InvoicePage extends StatelessWidget {
  final UserAccount user;
  final IuranData iuran;
  const InvoicePage({super.key, required this.user, required this.iuran});

  // Membuat PDF kuitansi lalu membuka dialog cetak/unduh
  Future<void> downloadInvoice(BuildContext context) async {
    final doc = pw.Document(); // dokumen PDF kosong
    doc.addPage(pw.Page(
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(24),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('KUITANSI PEMBAYARAN KOS', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('KosFinance'),
            pw.Divider(),
            pw.Text('Nama penghuni: ${user.name}'),
            pw.Text('Nomor kamar: ${iuran.roomNumber}'),
            pw.Text('Jenis pembayaran: ${iuran.iuranType}'),
            pw.Text('Tanggal jatuh tempo: ${iuran.dueDate}'),
            pw.Text('Tanggal pembayaran: ${iuran.paidAt == null ? '-' : formatDate(iuran.paidAt!)}'),
            pw.Text('Metode pembayaran: ${iuran.paymentMethod ?? '-'}'),
            pw.SizedBox(height: 12),
            pw.Text('Total dibayar: ${formatRupiah(iuran.amount)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Status: LUNAS'),
            pw.SizedBox(height: 30),
            pw.Text('Terima kasih telah melakukan pembayaran.'),
            pw.SizedBox(height: 10),
            pw.Text('Invoice demo dibuat oleh aplikasi KosFinance.'),
          ],
        ),
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'Kuitansi_KosFinance_${user.username}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kuitansi / Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.receipt_long, color: primaryGreen, size: 64),
          const SizedBox(height: 12),
          const Center(child: Text('KUITANSI PEMBAYARAN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const Divider(height: 30),
          InfoRow(label: 'Nama penghuni', value: user.name),
          InfoRow(label: 'Nomor kamar', value: iuran.roomNumber),
          InfoRow(label: 'Jenis pembayaran', value: iuran.iuranType),
          InfoRow(label: 'Tanggal pembayaran', value: iuran.paidAt == null ? '-' : formatDate(iuran.paidAt!)),
          InfoRow(label: 'Metode pembayaran', value: iuran.paymentMethod ?? '-'),
          InfoRow(label: 'Total dibayar', value: formatRupiah(iuran.amount)),
          const SizedBox(height: 12),
          const StatusChip(status: stLunas),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => downloadInvoice(context),
            icon: const Icon(Icons.download_outlined),
            label: const Text('UNDUH / CETAK PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
          ),
          const Text('Kuitansi hanya tersedia setelah pembayaran berstatus Sudah Dibayar.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

// ============================================================
// WIDGET REUSABLE (dipakai berulang di banyak halaman)
// ============================================================

// Kartu ringkasan angka (ikon + judul + nilai)
class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Judul bagian + tombol aksi opsional di kanan
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const SectionTitle({super.key, required this.title, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        if (actionText != null) TextButton(onPressed: onAction, child: Text(actionText!)),
      ],
    );
  }
}

// Bar horizontal perbandingan nominal
class FinancialBar extends StatelessWidget {
  final String title;
  final double amount;
  final double maxAmount;
  final Color color;

  const FinancialBar({
    super.key,
    required this.title,
    required this.amount,
    required this.maxAmount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Panjang bar = nominal dibanding nilai terbesar (0.0 - 1.0)
    final percentage = maxAmount == 0 ? 0.0 : amount / maxAmount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(formatRupiah(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 13,
              color: color,
              backgroundColor: color.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

// Kartu satu transaksi (dipakai di dashboard admin)
class TransactionCard extends StatelessWidget {
  final TransactionData transaction;

  const TransactionCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'Pemasukan';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome ? lightGreen : Colors.red.shade50,
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
        title: Text(transaction.description, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${transaction.date} • ${transaction.category}'),
            // Tombol lihat bukti jika ada
            if (transaction.proofBytes != null)
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: InteractiveViewer(
                        child: Image.memory(transaction.proofBytes!, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Lihat bukti pembayaran'),
              ),
          ],
        ),
        trailing: Text(
          formatRupiah(transaction.amount),
          style: TextStyle(
            color: isIncome ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// Label kecil berwarna (pill)
class Pill extends StatelessWidget {
  final String text;
  final Color color;

  const Pill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

// Label status pembayaran
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) => Pill(text: status, color: statusColor(status));
}

// Indikator 3 tahap pembayaran (Belum -> Menunggu -> Lunas)
class PaymentSteps extends StatelessWidget {
  final String status;

  const PaymentSteps({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    const labels = [stBelum, stProses, stLunas];
    final idx = labels.indexOf(status); // tahap saat ini
    final activeColor = statusColor(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) {
        final done = i <= idx; // tahap yang sudah tercapai diberi warna
        final c = done ? activeColor : Colors.grey.shade400;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: c,
                child: Icon(done ? Icons.check : Icons.circle_outlined, size: 15, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: c, fontWeight: i == idx ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// Kartu informasi satu kamar
class RoomCard extends StatelessWidget {
  final Room room;
  final bool showResident; // true = tampilkan info penghuni (tampilan admin)
  final List<Widget> actions; // tombol aksi tambahan

  const RoomCard({
    super.key,
    required this.room,
    this.showResident = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final type = roomTypes[room.typeIndex];
    // Sisa hari hanya relevan kalau kamar benar-benar aktif (Terisi)
    final days = room.status == 'Terisi' ? room.daysLeft : null;
    final urgent = days != null && days <= 7; // merah jika sisa <= 7 hari

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Kamar ${room.number}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Pill(text: room.status, color: roomColor(room.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(type.name, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                Pill(text: type.ac ? 'Ber-AC' : 'Tanpa AC', color: Colors.blue),
                Pill(text: type.wcDalam ? 'WC Dalam' : 'WC Luar', color: Colors.teal),
                if (type.discount > 0) Pill(text: 'Diskon ${type.discount}%', color: Colors.red),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${formatRupiah(type.finalPrice)} / bulan',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            // Info penghuni (khusus tampilan admin)
            if (showResident && room.residentName != null) ...[
              const Divider(height: 24),
              InfoRow(label: 'Penghuni', value: room.residentName!),
              if (room.checkIn != null) InfoRow(label: 'Mulai', value: formatDate(room.checkIn!)),
              if (room.checkOut != null) InfoRow(label: 'Berakhir', value: formatDate(room.checkOut!)),
              if (days != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Pill(
                    text: days < 0 ? 'Kontrak berakhir ${-days} hari lalu' : 'Sisa $days hari',
                    color: urgent ? Colors.red : Colors.green,
                  ),
                ),
            ],
            // Tombol aksi admin
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

// Kotak statistik kecil (angka + label)
class MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const MiniStat({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

// Baris label (kiri) + nilai (kanan). valueColor opsional, mis. merah untuk terlambat.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.grey))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

// Kartu satu data profil
class ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const ProfileInfoCard({super.key, required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: lightGreen,
          child: Icon(icon, color: primaryGreen),
        ),
        title: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}

// Tampilan saat data kosong
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // aman dipakai di dalam ListView
        children: [
          Icon(icon, size: 60, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
