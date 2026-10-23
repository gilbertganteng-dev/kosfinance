// ============================================================
// HELPER (fungsi bantu yang dipakai di banyak tempat)
// ============================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // membuka WhatsApp & Google Maps

import '../models/models.dart';
import 'constants.dart';

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

// Membaca tanggal transaksi dengan format dd/MM/yyyy.
DateTime? transactionDate(TransactionData transaction) => parseDate(transaction.date);

// Cek apakah transaksi berada di bulan tertentu
bool transactionInMonth(TransactionData transaction, DateTime month) {
  final date = transactionDate(transaction);
  return date != null && date.year == month.year && date.month == month.month;
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
