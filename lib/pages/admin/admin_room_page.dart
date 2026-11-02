// ============================================================
// ADMIN: KAMAR & PENGHUNI (cek kosong, penghuni, sisa hari)
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../../services/api_service.dart';
import '../../services/db_sync.dart';

class AdminRoomPage extends StatefulWidget {
  const AdminRoomPage({super.key});

  @override
  State<AdminRoomPage> createState() => _AdminRoomPageState();
}

class _AdminRoomPageState extends State<AdminRoomPage> {
  String filter = 'Semua'; // filter status kamar
  final Set<int> _busyRoomIds = <int>{};

  // Tempatkan akun penghuni yang sudah terdaftar melalui endpoint walk-in.
  Future<void> walkIn(Room room) async {
    if (room.id == null) {
      showMessage(context, 'ID kamar dari server tidak tersedia. Muat ulang data terlebih dahulu.');
      return;
    }

    final residents = accounts.where((account) =>
        account.role != 'Admin' &&
        account.id != null &&
        !rooms.any((item) => item.residentId == account.id && item.status != 'Kosong')).toList();
    if (residents.isEmpty) {
      showMessage(context, 'Belum ada akun penghuni yang dapat ditempatkan. Daftarkan akun penghuni terlebih dahulu.');
      return;
    }

    int? residentId = residents.first.id;
    final monthsController = TextEditingController(text: '1');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Isi Kamar ${room.number} (Walk-in)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: residentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Akun penghuni'),
                items: residents.map((resident) => DropdownMenuItem<int>(
                  value: resident.id,
                  child: Text('${resident.name} (${resident.username})', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (value) => setDialogState(() => residentId = value),
              ),
              const SizedBox(height: 12),
              field(monthsController, 'Durasi (1–24 bulan)', Icons.timelapse_outlined, type: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );

    final months = int.tryParse(monthsController.text.trim()) ?? 0;
    monthsController.dispose();
    if (confirmed != true) return;
    if (residentId == null || months < 1 || months > 24) {
      if (mounted) showMessage(context, 'Pilih penghuni dan durasi 1–24 bulan.');
      return;
    }

    setState(() => _busyRoomIds.add(room.id!));
    try {
      await ApiService.post('admin/walk-ins', {
        'resident_id': residentId,
        'room_id': room.id,
        'months': months,
      });
      await DbSync.loadAll();
      if (mounted) showMessage(context, 'Walk-in berhasil diproses. Tagihan awal dibuat di server.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } catch (_) {
      if (mounted) showMessage(context, 'Walk-in gagal. Periksa koneksi ke server.');
    } finally {
      if (mounted) setState(() => _busyRoomIds.remove(room.id));
    }
  }

  Future<void> _cancelBooking(Room room) async {
    if (room.id == null) return;
    final billMatches = iuranList.where((bill) =>
        bill.roomId == room.id && bill.kind == 'booking' && bill.status != stLunas).toList();
    if (billMatches.isEmpty) {
      showMessage(context, 'Tagihan booking aktif tidak ditemukan. Muat ulang data dan periksa status kamar.');
      return;
    }
    final ok = await confirmAction(context, 'Batalkan booking?', 'Booking ${room.residentName ?? ''} dibatalkan. Tagihan yang belum dibayar akan dihapus sesuai aturan server.');
    if (!ok || !mounted) return;
    setState(() => _busyRoomIds.add(room.id!));
    try {
      for (final bill in billMatches) {
        if (bill.status == stProses) {
          await ApiService.post('bills/${bill.id}/reject', {
            'reason': 'Booking dibatalkan oleh admin sebelum pembayaran dikonfirmasi.',
          });
        }
        if (bill.status == stBelum || bill.status == stKadaluarsa || bill.status == stProses) {
          await ApiService.delete('bills/${bill.id}');
        }
      }
      await DbSync.loadAll();
      if (mounted) showMessage(context, 'Booking berhasil dibatalkan.');
    } on ApiException catch (error) {
      await DbSync.loadAll();
      if (mounted) showMessage(context, error.message);
    } catch (_) {
      if (mounted) showMessage(context, 'Pembatalan gagal. Periksa koneksi server.');
    } finally {
      if (mounted) setState(() => _busyRoomIds.remove(room.id));
    }
  }

  Future<void> _requestExtension(Room room) async {
    if (room.id == null) return;
    final outstanding = iuranList.any((bill) => bill.roomId == room.id && bill.status != stLunas);
    if (outstanding) {
      showMessage(context, 'Selesaikan tagihan kamar ini sebelum membuat perpanjangan.');
      return;
    }
    setState(() => _busyRoomIds.add(room.id!));
    try {
      await ApiService.post('rooms/${room.id}/extensions', const {'months': 1});
      await DbSync.loadAll();
      if (mounted) showMessage(context, 'Tagihan perpanjangan 1 bulan dibuat. Tanggal checkout berubah setelah pembayaran lunas.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } catch (_) {
      if (mounted) showMessage(context, 'Tagihan perpanjangan gagal dibuat.');
    } finally {
      if (mounted) setState(() => _busyRoomIds.remove(room.id));
    }
  }

  Future<void> _checkout(Room room) async {
    if (room.id == null) return;
    final ok = await confirmAction(context, 'Kosongkan kamar?', 'Penempatan ${room.residentName ?? 'penghuni'} di kamar ${room.number} akan diakhiri setelah server memeriksa seluruh tagihan.');
    if (!ok || !mounted) return;
    setState(() => _busyRoomIds.add(room.id!));
    try {
      await ApiService.post('rooms/${room.id}/checkout', const <String, dynamic>{});
      await DbSync.loadAll();
      if (mounted) showMessage(context, 'Kamar berhasil dikosongkan.');
    } on ApiException catch (error) {
      if (mounted) showMessage(context, error.message);
    } catch (_) {
      if (mounted) showMessage(context, 'Checkout gagal. Periksa koneksi ke server.');
    } finally {
      if (mounted) setState(() => _busyRoomIds.remove(room.id));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          onPressed: _busyRoomIds.contains(room.id) ? null : () => walkIn(room),
                          icon: const Icon(Icons.person_add_alt),
                          label: const Text('Isi (Walk-in)'),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
                        ));
                      } else if (room.status == 'Dipesan') {
                        // Tidak ada tombol Check-in manual: kamar aktif otomatis setelah booking lunas.
                        actions.add(const Pill(text: 'Menunggu pembayaran lunas', color: Colors.orange));
                        actions.add(OutlinedButton(
                          onPressed: _busyRoomIds.contains(room.id) ? null : () => _cancelBooking(room),
                          child: const Text('Batalkan'),
                        ));
                      } else {
                        // Kamar terisi -> perpanjang / kosongkan
                        actions.add(OutlinedButton.icon(
                          onPressed: _busyRoomIds.contains(room.id) ? null : () => _requestExtension(room),
                          icon: const Icon(Icons.update),
                          label: const Text('Perpanjang 1 bln'),
                        ));
                        actions.add(OutlinedButton(
                          onPressed: _busyRoomIds.contains(room.id) ? null : () => _checkout(room),
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
