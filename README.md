# Skripsi Manager

Aplikasi manajemen skripsi offline-first berbasis Flutter untuk Android yang dirancang untuk membantu mahasiswa mengelola progress skripsi, menganalisis dokumen, dan mendeteksi plagiarisme dengan bantuan AI.

## Fitur Utama

### 1. **Manajemen Progress BAB Skripsi**
- Kelola bab-bab skripsi (Bab 1–5) dengan checklist tugas
- Hitung progress global berdasarkan tugas yang selesai
- Tambah, edit, atau hapus bab dan tugas secara dinamis
- Sistem streak harian untuk motivasi

### 2. **Import & Manajemen File**
- Unggah dan kelola file PDF/DOCX
- Metadata lengkap: nama, penulis, tahun, tag, catatan
- Kategorisasi: Jurnal, Skripsi, Referensi
- Pencarian berdasarkan nama, penulis, atau tag
- Filter berdasarkan tipe file dan kategori
- Urutkan berdasarkan nama, tanggal, atau ukuran
- Tandai favorit dan lacak file terakhir dibuka
- Buka file langsung di aplikasi eksternal

### 3. **AI Asisten via Gemini API**
- Muat file PDF/DOCX untuk konteks
- Pencarian paragraf offline
- Tanyakan pertanyaan tentang isi dokumen
- Riwayat chat AI persisten per dokumen
- Dukungan thread tanya-jawab lanjutan
- Ekstraksi referensi dan format
- Ekspor analisis ke riwayat
- Fallback ke OpenRouter jika Gemini gagal

### 4. **Mesin Perbandingan Kemiripan Dokumen (Plagiarisme)**
- Bandingkan dua dokumen secara side-by-side
- Deteksi kemiripan pada level paragraf
- Hitung skor dan persentase kemiripan
- Mode terjemahan: Normalisasi Bahasa Inggris ↔ Indonesia sebelum perbandingan
- Pemrosesan di background (tidak freeze UI)
- Cache dokumen untuk performa
- Simpan hasil ke riwayat analisis

### 5. **Akun & Profil**
- Profil pengguna: nama, tanggal lahir, judul skripsi
- Sistem streak harian (pelacakan aktivitas)
- Edit informasi profil

### 6. **Riwayat Analisis**
- Lihat semua analisis dan perbandingan tersimpan
- Ekspor ke TXT atau PDF
- Judul, tipe, isi, timestamp
- Refresh dan hapus entri riwayat
- Ekspor ke folder Download (Android)

### 7. **Autentikasi PIN Lokal**
- PIN 6-digit dengan keypad numerik
- Validasi PIN lokal (SQLite)
- Feedback haptic pada kesalahan
- Ubah/reset PIN
- Kontrol akses berbasis sesi

### 8. **Pengingat Harian Berbasis Notifikasi**
- Notifikasi harian untuk motivasi
- Pengaturan notifikasi di akun

## Password Awal Masuk
- **PIN Default:** `123123`
- Ubah PIN melalui menu Akun setelah login pertama.

## Tech Stack

- **Flutter** 3.x + Dart ^3.11.5
- **Riverpod** 2.6.1 — state management
- **SQLite (sqflite)** 2.4.1 — database lokal
- **Google Gemini 2.5 Flash** + **OpenRouter** — AI services
- **Google ML Kit** — terjemahan on-device (EN↔ID)
- **Syncfusion PDF** — ekstraksi teks PDF
- **Archive + XML** — parsing DOCX
- **Flutter Secure Storage** — penyimpanan PIN aman
- **File Picker, Path Provider, Open File** — manajemen file
- **Connectivity Plus** — deteksi koneksi
- **Flutter Local Notifications** — notifikasi

## Arsitektur Offline-First
- Semua data disimpan di SQLite lokal
- Pemrosesan file dan analisis berjalan offline
- AI menggunakan API cloud dengan fallback
- Terjemahan menggunakan model on-device ML Kit
- Aplikasi berfungsi penuh tanpa internet

## Setup & Instalasi

1. **Persiapan:**
   - Flutter 3.x SDK
   - Dart ^3.11.5
   - Android API 21+

2. **Konfigurasi API Keys:**
   - Salin `lib/core/secrets.dart.example` ke `lib/core/secrets.dart`
   - Isi dengan API key Gemini yang valid (rotasi jika perlu)
   - Pastikan file `secrets.dart` tidak di-commit ke git

3. **Build & Run:**
   ```bash
   flutter pub get
   flutter run
   ```

4. **Data Awal:**
   - 5 bab skripsi (Bab 1–5) dibuat otomatis
   - Profil akun default dibuat
   - PIN default: `123123`

## Build Release
```bash
flutter pub get
flutter build apk --release
```

## Developer
Adhi Wibowo — Version 1.2.0+3

## Catatan Keamanan
- API keys Gemini dan OpenRouter terpapar di kode sumber. Gunakan template `secrets.dart.example` dan kecualikan dari git.
- PIN disimpan di database lokal SQLite.
