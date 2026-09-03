# Design Document: Admin Soft Delete User Feature

**Tanggal:** 2026-09-03  
**Topik:** Fitur Hapus Pengguna (Soft Delete oleh Admin dengan Penghilangan di Frontend & Penolakan Login)

---

## 1. Latar Belakang & Tujuan
Aplikasi Money Tracker membutuhkan fitur bagi Administrator untuk dapat menghapus pengguna dari antarmuka Kelola Pengguna (*User Management*). Untuk menjaga integritas referensial data transaksi, akun dihapus secara *soft delete* di backend (Supabase), namun di sisi frontend (*UI mobile*), pengguna tersebut akan menghilang sepenuhnya dari daftar pengguna.

Selain itu, pengguna yang berstatus tidak aktif (`is_active = false`) dilarang melakukan login dan akan mendapatkan pesan penolakan yang sama seperti kesalahan kredensial standar:
> *"Username/Email atau password salah. Silakan periksa kembali."*

---

## 2. Arsitektur & Spesifikasi Detail

### 2.1 Backend (Supabase PostgreSQL)
1. **Perubahan Skema `public.profiles`**:
   - Kolom `is_active BOOLEAN DEFAULT TRUE NOT NULL`.
   - Data user yang sudah ada sebelumnya dipastikan memiliki nilai `is_active = TRUE`.

2. **Fungsi RPC `admin_soft_delete_user(target_user_id UUID)`**:
   - Berjalan dengan hak akses `SECURITY DEFINER`.
   - **Proteksi Diri:** Memeriksa apakah target adalah admin pemanggil (`target_user_id == auth.uid()`). Jika sama, tolak dengan pengecualian (*exception*).
   - **Soft Delete:** Mengubah status `is_active = FALSE` dan `updated_at = now()` pada tabel `public.profiles`.
   - **Metadata Sync:** Menandai `raw_user_meta_data` di `auth.users` dengan `'is_active': false`.

3. **Reaktivasi Akun:**
   - Dilakukan langsung oleh Admin melalui Supabase Dashboard / SQL Editor:
     ```sql
     UPDATE public.profiles SET is_active = true WHERE email = 'target@example.com';
     ```

### 2.2 Model & Service Layer (Dart)

1. **`UserModel` (`lib/auth/models/user_model.dart`)**:
   - Field `final bool isActive;` dengan nilai default `true`.
   - Perbaikan deserialisasi `fromJson`: Menangani nilai `null` sebagai `true` agar akun lama yang belum terisi kolomnya tidak dianggap tidak aktif.

2. **`UserManagementService` (`lib/user_management/services/user_management_service.dart`)**:
   - `fetchUsersList()`: Menambahkan klausa filter `.eq('is_active', true)` (atau `.neq('is_active', false)`) sehingga user nonaktif **tidak pernah dimuat atau ditampilkan** di antarmuka mobile.
   - `adminDeleteUser(String userId)`: Menjalankan pemanggilan RPC `admin_soft_delete_user` ke Supabase.

3. **`AuthService` (`lib/auth/services/auth_service.dart`)**:
   - `_enrichUserModelWithProfile(User user)`: Mengambil kolom `is_active` dari `public.profiles`.
   - `login()`:
     - Sebelum/sesudah `signInWithPassword`, periksa apakah `userModel.isActive == false`.
     - Jika `false`, segera batalkan sesi (`await client.auth.signOut()`) dan bersihkan state token.
     - Kembalikan error autentikasi generik:
       `"Username/Email atau password salah. Silakan periksa kembali."`
     - Hal ini menyamarkan fakta bahwa akun dinonaktifkan, sehingga orang luar/user tidak mengetahui mekanisme internal sistem.

### 2.3 Antarmuka Pengguna (UI) & Interaksi

1. **Proteksi Admin Login Saat Ini**:
   - Kartu pengguna yang memiliki ID sama dengan ID akun Admin yang sedang login **tidak akan menampilkan tombol hapus**.
2. **Tombol Hapus & Dialog Konfirmasi**:
   - Pada kartu pengguna lain di [`user_management_screen.dart`](file:///D:/app/New-folder/money-tracker/lib/user_management/presentation/user_management_screen.dart), di samping tombol reset password terdapat tombol tempat sampah warna merah (`Icons.delete_outline_rounded`).
   - Mengklik tombol memunculkan dialog konfirmasi bahaya:
     - Judul: **Hapus Pengguna?**
     - Pesan: *"Apakah Anda yakin ingin menghapus akun [Nama Pengguna]? Pengguna ini tidak akan dapat login kembali."*
     - Tombol aksi: **Batal** dan **Hapus** (warna merah bahaya).
3. **Pembaruan State UI Responsif**:
   - Saat konfirmasi Hapus ditekan, tampilkan indikator loading.
   - Jika sukses, user langsung dihapus dari daftar lokal `_allUsers` dan `_filteredUsers`, serta menampilkan SnackBar konfirmasi: *"Pengguna [Nama] berhasil dihapus."*

---

## 3. Rencana Pengujian & Validasi
- **Static Analysis:** Jalankan `dart analyze` (harus 0 errors dan 0 warnings).
- **Unit Test:** Tambahkan unit test untuk `UserModel.fromJson` (terkait `is_active`), `UserManagementService.deleteUser`, dan `AuthService.login` rejection ketika `isActive == false`.
- **Regresi UI:** Memastikan scroll list di `UserManagementScreen` tetap 60 FPS dan tombol hapus tidak muncul pada kartu user sendiri.
