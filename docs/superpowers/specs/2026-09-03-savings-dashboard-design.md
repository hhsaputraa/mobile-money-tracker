# Design Document: Savings System & Dashboard Overhaul

**Tanggal:** 2026-09-03  
**Topik:** Perombakan Total Halaman Dashboard Menjadi Sistem Tabungan (Penabung vs Admin CRUD)

---

## 1. Latar Belakang & Tujuan
Tujuan akhir dari aplikasi Money Tracker adalah memberikan wadah pencatatan tabungan nasabah (penabung), di mana:
1. **Admin** dapat melakukan pencatatan dan pengelolaan saldo masuk/setoran nasabah (CRUD Transaksi Setoran).
2. **Nasabah (Penabung)** dapat memantau total saldo tabungan miliknya sendiri dan riwayat transaksi setorannya secara transparan (*read-only*).
3. Halaman utama (Dashboard) dirombak total dari sekadar tampilan status server menjadi pusat kendali keuangan tabungan yang terbagi sesuai peran (*role-based view*).

---

## 2. Arsitektur & Spesifikasi Detail

### 2.1 Skema Database & Keamanan (Supabase PostgreSQL)
1. **Tabel `public.savings_transactions`**:
   - `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`
   - `user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE`
   - `amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0)`
   - `type VARCHAR(20) NOT NULL DEFAULT 'deposit'`
   - `description TEXT`
   - `transaction_date TIMESTAMPTZ NOT NULL DEFAULT now()`
   - `created_by UUID REFERENCES public.profiles(id)`
   - `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
   - `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`

2. **Indeks Performa**:
   - `CREATE INDEX idx_savings_user_date ON public.savings_transactions (user_id, transaction_date DESC);`

3. **Row Level Security (RLS)**:
   - Pengguna dengan `auth.uid() == user_id` hanya dapat membaca (`SELECT`) data miliknya sendiri.
   - Admin (`profiles.is_admin = true`) memiliki akses penuh (`ALL`: `SELECT`, `INSERT`, `UPDATE`, `DELETE`).

4. **Fungsi Agregasi PostgreSQL (RPC)**:
   - `get_my_savings_summary()`: Mengembalikan JSON `{ total_balance, total_transactions }` untuk nasabah login saat ini.
   - `get_admin_savings_summary()`: Mengembalikan JSON `{ total_savings_pool, total_transactions_count, active_customers_count }` untuk Admin.

---

### 2.2 Model & Service Layer (Dart)

1. **`SavingsTransactionModel` (`lib/savings/models/savings_transaction_model.dart`)**:
   - Atribut: `id`, `userId`, `userName`, `userEmail`, `amount`, `type`, `description`, `transactionDate`, `createdBy`, `createdAt`.
   - Helper:
     - `formattedAmount`: Format mata uang Indonesia `Rp 1.500.000`.
     - `formattedDate`: Format tanggal Indonesia `03 Sep 2026, 14:30`.
   - Serialisasi `fromJson` dan `toJson`.

2. **`SavingsSummaryModel` (`lib/savings/models/savings_summary_model.dart`)**:
   - Menyimpan saldo nasabah atau statistik admin secara terstruktur dan aman.

3. **`SavingsService` (`lib/savings/services/savings_service.dart`)**:
   - Mematuhi Single Responsibility Principle (SRP):
     - `getMyTotalBalance()`
     - `getMyTransactions()`
     - `getAdminOverview()`
     - `getAllTransactions({String? filterUserId, String? query})`
     - `getActiveCustomersList()` (mengambil penabung dengan `is_active = true AND is_admin = false`)
     - `createTransaction({required String userId, required double amount, String? description, DateTime? transactionDate})`
     - `updateTransaction({required String transactionId, required double amount, String? description, DateTime? transactionDate})`
     - `deleteTransaction(String transactionId)`

---

### 2.3 Antarmuka Pengguna (UI) di `DashboardScreen`

#### A. Tampilan Nasabah (Penabung / `!isAdmin`)
1. **Header Sapaan:** Ucapan "Halo, [Nama Penabung]" dan tanggal saat ini.
2. **Kartu Saldo Tabungan Utama (*Savings Balance Card*):**
   - Nuansa warna hijau emerald elegan (`LinearGradient`).
   - Teks "Total Saldo Tabungan Anda".
   - Nominal Rupiah dengan tombol sembunyikan/tampilkan saldo (`Icons.visibility` / `Icons.visibility_off`).
   - Info ringkas: total frekuensi setoran yang tercatat.
3. **Riwayat Setoran Tabungan:**
   - Menampilkan daftar setoran terbaru dengan nominal bertanda `+ Rp ...`, tanggal, dan catatan.
   - Status kosong (*empty state*) yang ramah jika belum ada setoran yang diinputkan.
   - Mendukung *Pull-to-Refresh*.

#### B. Tampilan Administrator (`isAdmin`)
1. **Header Admin:** Nama Admin dan penanda hak akses administrator.
2. **Kartu Ringkasan Tabungan (*Admin Overview Card*):**
   - Menampilkan total akumulasi tabungan seluruh nasabah.
   - Statistik ringkas: Jumlah nasabah aktif & total seluruh transaksi.
   - Dua tombol aksi cepat:
     - **`+ Input Setoran`**: Membuka dialog input setoran saldo baru.
     - **`Kelola Pengguna`**: Navigasi ke halaman User Management.
3. **Filter & Pencarian:**
   - Dropdown filter: Pilihan *"Semua Nasabah"* atau salah satu nasabah aktif.
   - TextField pencarian keterangan/nama nasabah.
4. **Daftar Transaksi Seluruh Nasabah (CRUD):**
   - Menampilkan kartu transaksi: Nama Nasabah, nominal, tanggal, keterangan.
   - Tombol **Edit** (ikon pensil): Membuka dialog edit nominal dan keterangan.
   - Tombol **Hapus** (ikon sampah merah): Menampilkan konfirmasi hapus transaksi.
5. **Dialog Input / Edit Setoran (`TransactionDialog`):**
   - Dropdown pemilihan nasabah (dari daftar penabung aktif).
   - Input nominal rupiah.
   - Input tanggal setoran.
   - Input catatan/keperluan setoran.
   - Validasi ketat (nominal harus > 0, nasabah wajib dipilih).

---

## 3. Rencana Pengujian & Validasi
- **Unit Tests:** Pengujian model `SavingsTransactionModel` (serialisasi, parsing, format nominal).
- **Widget Tests:** Pengujian tampilan `DashboardScreen` untuk role Penabung (menampilkan kartu saldo & riwayat) dan role Admin (menampilkan ringkasan seluruh nasabah & tombol input setoran).
- **Static Analysis:** `dart analyze` harus menghasilkan 0 errors dan 0 warnings.
