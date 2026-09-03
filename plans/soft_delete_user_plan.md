# Rencana Fitur: Admin Soft Delete Pengguna

**Tanggal:** 2026-09-03  
**Status:** Approved  
**Spesifikasi:** `docs/superpowers/specs/2026-09-03-soft-delete-user-design.md`

---

## Ringkasan
Implementasi fitur Soft Delete untuk Administrator pada modul User Management, dengan perilaku:
1. Pengguna berstatus `is_active = false` di backend Supabase.
2. Pengguna yang dihapus menghilang sepenuhnya dari daftar UI di aplikasi mobile.
3. Pengguna yang dihapus/nonaktif tidak bisa login, dan menampilkan notifikasi kesalahan generik: *"Username/Email atau password salah. Silakan periksa kembali."*
4. Reaktivasi dapat dilakukan secara langsung oleh admin di Supabase.
