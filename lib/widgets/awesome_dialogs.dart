import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'animations.dart' show CountUpNumber;

/// Warna hijau gelap khas WhatsApp untuk gradien header.
const Color _waDark = Color(0xFF128C7E);

/// Format status mentah ('hadir') menjadi label ber-emoji khas WhatsApp,
/// sama seperti pesan yang dikirim lewat WhatsApp.
const Map<String, String> _statusEmoji = {
  'hadir': '✅ Hadir',
  'izin': '📝 Izin',
  'sakit': '🤒 Sakit',
  'alpa': '❌ Alpa',
};

/// Format status mentah ('hadir') menjadi label ber-emoji khas WhatsApp,
/// misalnya '✅ Hadir'. Dipakai untuk pratinjau & chip status di popup.
String formatStatusWa(String status) => _statusEmoji[status] ?? status;

/// Entri popup: muncul membesar + memudar dengan sedikit pantulan (bounce).
///
/// Menghormati pengaturan aksesibilitas "kurangi gerakan": konten tampil
/// langsung tanpa animasi.
class _DialogEntrance extends StatelessWidget {
  final Widget child;

  const _DialogEntrance({required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: t, child: child),
      ),
    );
  }
}

/// Denyut halus: elemen membesar-kecil perlahan terus-menerus.
///
/// Menghormati pengaturan aksesibilitas "kurangi gerakan": elemen diam.
class _Pulse extends StatefulWidget {
  final Widget child;

  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _scale = Tween(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _scale,
      child: widget.child,
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
    );
  }
}

/// Centang sukses yang "menggambar dirinya sendiri": garis centang muncul
/// bertahap dari awal hingga akhir, di dalam lingkaran gradien yang berkilau.
///
/// Menghormati pengaturan aksesibilitas "kurangi gerakan": centang tampil
/// utuh langsung tanpa animasi.
class AnimatedCheckmark extends StatelessWidget {
  final double size;
  final Color color;
  final Color backgroundColor;
  final Duration duration;
  final double strokeWidth;

  const AnimatedCheckmark({
    super.key,
    this.size = 110,
    this.color = Colors.white,
    this.backgroundColor = AppColors.whatsapp,
    this.duration = const Duration(milliseconds: 700),
    this.strokeWidth = 9,
  });

  @override
  Widget build(BuildContext context) {
    final progress = MediaQuery.disableAnimationsOf(context) ? 1.0 : null;
    if (progress != null) return _body(progress);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => _body(value),
    );
  }

  Widget _body(double progress) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.whatsapp, _waDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.whatsapp.withValues(alpha: 0.45),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _CheckmarkPainter(
          progress: progress,
          color: color,
          strokeWidth: strokeWidth,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.26, size.height * 0.53)
      ..lineTo(size.width * 0.44, size.height * 0.70)
      ..lineTo(size.width * 0.76, size.height * 0.34);

    final metrics = path.computeMetrics().first;
    canvas.drawPath(
      metrics.extractPath(0, metrics.length * progress),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Particle {
  final double dx; // posisi horizontal ternormalisasi 0..1
  final double radius;
  final double speed; // kecepatan siklus (relatif terhadap durasi controller)
  final double phase; // pergeseran fase agar tidak serempak
  final Color color;

  const _Particle({
    required this.dx,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.color,
  });
}

/// Partikel kecil (titik-titik hijau) yang naik melayang dari bawah ke atas
/// sambil memudar — memberi kesan perayaan/confetti yang tenang.
///
/// Menghormati pengaturan aksesibilitas "kurangi gerakan": tidak ada
/// partikel yang bergerak (area kosong).
class RisingParticles extends StatefulWidget {
  final int count;
  final Duration duration;
  final Color color;

  const RisingParticles({
    super.key,
    this.count = 14,
    this.duration = const Duration(seconds: 4),
    this.color = AppColors.whatsapp,
  });

  @override
  State<RisingParticles> createState() => _RisingParticlesState();
}

class _RisingParticlesState extends State<RisingParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    // Random dengan seed tetap agar posisi partikel konsisten (tidak flaky).
    final rng = math.Random(42);
    final tints = [
      widget.color,
      widget.color.withValues(alpha: 0.6),
      _waDark,
      Colors.white,
    ];
    _particles = List.generate(widget.count, (i) {
      return _Particle(
        dx: rng.nextDouble(),
        radius: 2 + rng.nextDouble() * 4,
        speed: 0.7 + rng.nextDouble() * 0.6,
        phase: rng.nextDouble(),
        color: tints[i % tints.length],
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _ParticlesPainter(
          progress: _controller.value,
          particles: _particles,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  _ParticlesPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress * p.speed + p.phase) % 1.0;
      final y = size.height * (1 - t);
      final opacity = math.sin(math.pi * t).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(p.dx * size.width, y),
        p.radius,
        Paint()..color = p.color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Popup konfirmasi kirim notifikasi WhatsApp.
///
/// Menampilkan header gradien hijau WhatsApp, contoh pesan yang akan dikirim,
/// jumlah penerima (dengan animasi count-up), dan tombol Batal/Kirim.
class WhatsAppConfirmDialog extends StatelessWidget {
  final int jumlahOrangTua;
  final int totalSiswa;
  final String kelas;
  final String tanggal; // format 'dd/MM/yyyy'
  final String namaContoh;
  final String statusContoh; // status mentah: 'hadir', 'izin', dst.

  const WhatsAppConfirmDialog({
    super.key,
    required this.jumlahOrangTua,
    required this.totalSiswa,
    required this.kelas,
    required this.tanggal,
    required this.namaContoh,
    required this.statusContoh,
  });

  String get _pesanContoh {
    final status = formatStatusWa(statusContoh);
    return '*Rekap Absensi Harian - SAM*\n\n'
        'Yth. Orang Tua/Wali,\n\n'
        'Berikut rekap kehadiran putra/i Anda hari ini:\n\n'
        '👤 Nama: *$namaContoh*\n'
        '📋 Status: $status\n'
        '📅 Tanggal: $tanggal\n\n'
        'Terima kasih.\n'
        '- Guru SMA AS-SAMA AMBON';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: _DialogEntrance(
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            // Scrollable agar tetap aman di layar kecil / mode lanskap.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  _buildPreview(context),
                  _buildInfoRow(context),
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.whatsapp, _waDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _Pulse(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.chat_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kirim Notifikasi WA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rekap Absensi Harian • Kelas $kelas',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F8EC),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(
              color: AppColors.whatsapp.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Contoh pesan yang akan dikirim',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _waDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _pesanContoh,
                maxLines: 9,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.whatsapp.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: AppColors.whatsapp,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Dikirim ke ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                    CountUpNumber(
                      value: jumlahOrangTua,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.whatsapp,
                      ),
                    ),
                    const Text(
                      ' orang tua',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'dari total $totalSiswa siswa di kelas ini',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.whatsapp,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: AppColors.whatsapp,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send_rounded, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Kirim Sekarang',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Popup hasil pengiriman notifikasi WhatsApp.
///
/// Mendukung dua konteks:
/// - Rekap kelas (banyak siswa): statistik berhasil/gagal dengan animasi
///   count-up; sukses penuh = centang menggambar diri + partikel perayaan,
///   sebagian gagal = lingkaran peringatan kuning-oranye.
/// - Absensi per siswa (scan): tampilkan [namaSiswa], [statusLabel], dan
///   kasus [waSkipped] (tanpa nomor HP) berupa lingkaran info biru tanpa
///   statistik. [onDone] dipanggil saat popup ditutup.
class WhatsAppResultDialog extends StatelessWidget {
  final int berhasil;
  final int gagal;
  final String? kelas;
  final String tanggal; // format 'dd/MM/yyyy'
  final String? namaSiswa;
  final String? statusLabel; // label ber-emoji, mis. '✅ Hadir'
  final bool waSkipped; // kirim dilewati karena nomor HP orang tua kosong
  final VoidCallback? onDone; // dipanggil saat popup ditutup

  const WhatsAppResultDialog({
    super.key,
    required this.berhasil,
    required this.gagal,
    this.kelas,
    required this.tanggal,
    this.namaSiswa,
    this.statusLabel,
    this.waSkipped = false,
    this.onDone,
  });

  /// Semua notifikasi terkirim (dan bukan kasus yang dilewati).
  bool get _suksesSemua => !waSkipped && berhasil > 0 && gagal == 0;

  String get _title {
    if (_suksesSemua) return 'Notifikasi Terkirim 🎉';
    if (waSkipped) return 'Absen Tersimpan';
    return namaSiswa != null ? 'WA Gagal Terkirim' : 'Sebagian Gagal Terkirim';
  }

  String get _subtitle {
    if (_suksesSemua) {
      return namaSiswa != null
          ? 'Notifikasi WhatsApp berhasil dikirim ke orang tua $namaSiswa.'
          : 'Semua pesan WhatsApp berhasil dikirim ke orang tua siswa.';
    }
    if (waSkipped) {
      return 'Nomor HP orang tua belum diisi. Isi di menu Data Siswa.';
    }
    return namaSiswa != null
        ? 'Pesan WhatsApp untuk $namaSiswa tidak terkirim. Cek token Fonnte di whatsapp_service.dart.'
        : 'Beberapa pesan tidak terkirim. Anda dapat mencoba kirim ulang nanti.';
  }

  void _selesai(BuildContext context) {
    onDone?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: _DialogEntrance(
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            // Scrollable agar tetap aman di layar kecil / mode lanskap.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 26),
                  _buildBadge(),
                  const SizedBox(height: 8),
                  _buildTitle(context),
                  // Statistik hanya relevan bila pengiriman benar-benar
                  // dilakukan (bukan kasus dilewati karena tanpa nomor HP).
                  if (!waSkipped) ...[
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              icon: Icons.check_circle_rounded,
                              label: 'Berhasil',
                              value: berhasil,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.error_rounded,
                              label: 'Gagal',
                              value: gagal,
                              color: gagal > 0 ? Colors.red : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => _selesai(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Selesai',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    // Sukses penuh: centang hijau menggambar diri + partikel perayaan.
    if (_suksesSemua) {
      return SizedBox(
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: RisingParticles(color: AppColors.whatsapp),
              ),
            ),
            const AnimatedCheckmark(size: 110),
          ],
        ),
      );
    }

    // Tanpa nomor HP: lingkaran info biru yang berdenyut.
    if (waSkipped) {
      return SizedBox(
        height: 160,
        child: Center(
          child: _Pulse(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.accent, Color(0xFF0E7490)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    // Sebagian gagal: lingkaran peringatan kuning-oranye yang berdenyut.
    return SizedBox(
      height: 160,
      child: Center(
        child: _Pulse(
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.warning, Color(0xFFF97316)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.warning.withValues(alpha: 0.4),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Column(
      children: [
        Text(
          _title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
        if (statusLabel != null) _buildStatusChip(),
        const SizedBox(height: 8),
        Text(
          kelas != null ? 'Kelas $kelas • $tanggal' : tanggal,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_note_rounded,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            statusLabel!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu statistik kecil (Berhasil / Gagal) dengan angka count-up.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          CountUpNumber(
            value: value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Popup konfirmasi generik dengan gaya baru (kartu membulat + animasi masuk).
///
/// Menampilkan lencana ikon berwarna, judul, pesan, konten tambahan opsional
/// ([detail]), serta dua tombol: Batal dan konfirmasi berwarna. Hasil pop
/// `true`/`false`.
class AwesomeConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String cancelText;
  final String confirmText;
  final IconData confirmIcon;
  final Widget? detail;

  const AwesomeConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.cancelText = 'Batal',
    this.confirmText = 'Ya',
    this.confirmIcon = Icons.check_rounded,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: _DialogEntrance(
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            // Scrollable agar tetap aman di layar kecil / mode lanskap.
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(icon, color: color, size: 34),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: AppColors.muted,
                      ),
                    ),
                    if (detail != null) ...[const SizedBox(height: 14), detail!],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.foreground,
                                side: const BorderSide(
                                  color: AppColors.border,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                cancelText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context, true),
                              icon: Icon(confirmIcon, size: 18),
                              label: Text(
                                confirmText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: color,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Popup pemuatan generik dengan gaya baru: kartu membulat + animasi masuk.
class AwesomeLoadingDialog extends StatelessWidget {
  final String message;

  const AwesomeLoadingDialog({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: _DialogEntrance(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Popup sukses generik dengan gaya yang sama seperti popup notifikasi WA:
/// centang yang menggambar diri + partikel perayaan + judul + deskripsi.
///
/// Dipakai misalnya setelah berhasil menambah guru atau siswa. [onDone]
/// dipanggil saat tombol penutup ditekan.
class AwesomeSuccessDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String confirmText;
  final IconData confirmIcon;
  final VoidCallback? onDone;

  const AwesomeSuccessDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.confirmText = 'Selesai',
    this.confirmIcon = Icons.check_rounded,
    this.onDone,
  });

  void _selesai(BuildContext context) {
    onDone?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: _DialogEntrance(
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            // Scrollable agar tetap aman di layar kecil / mode lanskap.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 26),
                  SizedBox(
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: RisingParticles(color: AppColors.whatsapp),
                          ),
                        ),
                        const AnimatedCheckmark(size: 110),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => _selesai(context),
                        icon: Icon(confirmIcon, size: 18),
                        label: Text(
                          confirmText,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
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
