/// Arum — AI Academic Assistant branding constants and response utilities.
///
/// Semua teks UI yang berhubungan dengan AI assistant menggunakan konstanta
/// dari file ini agar branding konsisten di seluruh aplikasi.
abstract final class Arum {
  // ── Branding ─────────────────────────────────────────────────────────────────

  static const String name = 'Arum';
  static const String tagline = 'Teman Sharing Skripsimu';
  static const String roleLabel = 'Arum';
  static const String userLabel = 'Kamu';

  // ── UI strings ────────────────────────────────────────────────────────────────

  static const String askButton = 'Tanya Arum';
  static const String followUpHint = 'Tanya lagi ke Arum...';
  static const String askHint = 'Tulis pertanyaan kamu...';
  static const String processingLabel = 'Arum sedang memproses...';
  static const String historyTitle = 'Riwayat Arum';
  static const String savedMessage = 'Percakapan tersimpan ke riwayat.';
  static const String copiedMessage = 'Jawaban Arum disalin.';

  // ── Smart text cleaner ───────────────────────────────────────────────────────

  /// Bersihkan output AI sebelum ditampilkan:
  /// - Normalize line breaks berlebihan
  /// - Rapikan bullet points
  /// - Hapus trailing whitespace per baris
  /// - Perbaiki spasi setelah markdown markers
  /// - Tidak mengubah isi jawaban, hanya formatting
  static String clean(String raw) {
    if (raw.isEmpty) return raw;

    var text = raw;

    // 1. Normalkan CRLF → LF
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 2. Rapikan spasi setelah bullet markers (* - •)
    text = text.replaceAll(RegExp(r'^([*\-•])\s{2,}', multiLine: true), r'$1 ');

    // 3. Pastikan ada spasi setelah ## heading markers
    text = text.replaceAll(
      RegExp(r'^(#{1,4})([^\s#])', multiLine: true),
      r'$1 $2',
    );

    // 4. Hapus trailing spaces per baris
    text = text
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n');

    // 5. Maksimal 2 baris kosong berturut-turut
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 6. Hapus leading/trailing whitespace keseluruhan
    text = text.trim();

    return text;
  }
}
