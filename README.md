# Skripsi Manager

Aplikasi manajemen skripsi berbasis Flutter dengan pendekatan offline-first untuk membantu mahasiswa mengelola progress skripsi, menganalisis dokumen, mendeteksi kemiripan tulisan, dan berdiskusi dengan AI secara lebih terorganisir.

## Fitur Utama

### Manajemen Progress Skripsi

- Kelola BAB skripsi (Bab 1–5)
- Checklist tugas per BAB
- Progress global otomatis
- Tambah, edit, dan hapus tugas
- Sistem streak harian untuk menjaga konsistensi pengerjaan

---

### Import & Manajemen Dokumen

- Import file PDF dan DOCX
- Metadata lengkap:
  - nama file
  - penulis
  - tahun
  - tag
  - catatan
- Kategori dokumen:
  - Jurnal
  - Skripsi
  - Referensi
- Search dan filter dokumen
- Sorting berdasarkan nama, tanggal, dan ukuran
- Favorite documents
- Last opened tracking
- Buka file langsung menggunakan aplikasi eksternal

---

### Arum — Teman Sharing Skripsimu

Asisten AI terintegrasi untuk membantu proses penulisan dan analisis skripsi.

#### Fitur AI

- Chat AI berbasis konteks dokumen
- Tanya jawab lanjutan dengan context memory
- Riwayat percakapan persisten
- Parsing PDF dan DOCX
- Pencarian paragraf offline
- Analisis isi dokumen
- Ekstraksi referensi
- Formatting bantuan akademik
- Markdown rendering yang lebih rapi

#### AI Providers

1. Gemini 2.5 Flash
2. DeepSeek V4 Flash
3. OpenRouter (fallback)

#### Sistem Fallback Otomatis

Jika provider utama gagal:

Gemini → DeepSeek → OpenRouter

---

### Mesin Perbandingan Kemiripan Dokumen

Fitur analisis kemiripan tulisan berbasis paragraf.

#### Kemampuan

- Perbandingan dua dokumen side-by-side
- Deteksi kemiripan paragraf
- Persentase similarity
- Skor kemiripan
- Highlight bagian serupa
- Cache dokumen untuk performa lebih cepat

#### Mode Translasi

Normalisasi Bahasa Indonesia ↔ Inggris sebelum proses perbandingan menggunakan Google ML Kit on-device.

---

### Riwayat Analisis

- Simpan hasil analisis AI
- Simpan riwayat percakapan penuh
- Riwayat compare dokumen
- Export TXT & PDF
- Timestamp otomatis
- Hapus dan refresh riwayat
- Export ke folder Download Android

---

### Akun & Profil

- Nama pengguna
- Tanggal lahir
- Judul skripsi
- Tracking streak harian
- Pengaturan AI
- Pengaturan notifikasi

---

### Sistem Keamanan Lokal

- Login PIN 6 digit
- Validasi lokal menggunakan SQLite
- Haptic feedback
- Reset & ubah PIN
- Session-based access

---

### Pengingat Harian

- Notifikasi harian
- Reminder pengerjaan skripsi
- Pengaturan notifikasi di halaman akun

---

# Tech Stack

| Technology | Usage |
|---|---|
| Flutter 3.x | Cross-platform framework |
| Dart | Programming language |
| Riverpod | State management |
| SQLite (sqflite) | Local database |
| Gemini API | AI provider |
| DeepSeek API | AI provider |
| OpenRouter | AI fallback provider |
| Google ML Kit | On-device translation |
| Syncfusion PDF | PDF text extraction |
| Archive + XML | DOCX parsing |
| Flutter Secure Storage | Secure local storage |
| File Picker | File management |
| Open File | Open external files |
| Connectivity Plus | Network detection |
| Flutter Local Notifications | Local notifications |

---

# Arsitektur Offline-First

Skripsi Manager dirancang agar tetap dapat digunakan tanpa koneksi internet.

## Offline Features

- SQLite local storage
- File parsing lokal
- Document comparison offline
- ML Kit translation on-device
- Progress & history tersimpan lokal

## Online Features

- AI provider integration
- Cloud AI processing

---

# Setup & Instalasi

## 1. Requirements

- Flutter 3.x
- Dart SDK
- Android SDK API 21+

---

## 2. Konfigurasi API Key

Buat file berikut:

```bash
lib/core/secrets.dart
```

Lalu isi API key sesuai provider yang digunakan di dalam file tersebut.

Contoh struktur dan lokasi pengisian sudah tersedia pada:

```bash
lib/core/secrets.dart.example
```

Pastikan:

- `secrets.dart` masuk `.gitignore`
- jangan commit API key ke repository publik

---

## 3. Install Dependency

```bash
flutter pub get
```

---

## 4. Jalankan Aplikasi

```bash
flutter run
```

---

# Data Awal

## Default PIN

```text
123123
```

Disarankan segera mengganti PIN setelah login pertama.

---

# Build Release APK

## APK Standard

```bash
flutter build apk --release
```

## APK Lebih Ringan

```bash
flutter build apk --release --split-per-abi
```

Output build:

```text
build/app/outputs/flutter-apk/
```

---

# Optimasi yang Sudah Diterapkan

- Offline-first architecture
- Background processing
- Async document analysis
- AI fallback system
- Cache optimization
- Lightweight markdown rendering
- Optimized history rendering
- Reduced unnecessary rebuilds

---

# Developer

Adhi Wibowo

Version mengikuti `pubspec.yaml`

---

# Catatan Keamanan

- Jangan commit file `secrets.dart`
- Gunakan `.gitignore`
- API key bersifat private
- PIN disimpan secara lokal
- Tidak ada cloud database untuk data pengguna

---

# Catatan

Aplikasi ini masih terus dikembangkan untuk membantu mahasiswa mengelola skripsi dengan workflow yang lebih modern, ringan, dan terorganisir melalui pendekatan offline-first dan bantuan AI.
