// ============================================================
// ADMIN: KAMAR & PENGHUNI (cek kosong, penghuni, sisa hari)
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

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
