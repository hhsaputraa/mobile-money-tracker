-- ==============================================================================
-- Migration: Admin Soft Delete User Feature & Bidirectional Re-activation Sync
-- Description:
-- 1. Pastikan ekstensi pgcrypto aktif
-- 2. Tambahkan kolom is_active pada public.profiles secara aman jika belum ada
-- 3. Update nilai NULL pada is_active menjadi TRUE
-- 4. Fungsi RPC admin_soft_delete_user(target_user_id UUID)
-- 5. Trigger otomatis agar jika is_active diubah di public.profiles, auth.users ikut tersinkronkan
-- 6. Sinkronisasi data saat ini antara public.profiles dan auth.users
-- 7. Hak akses EXECUTE dan reload schema PostgREST
-- ==============================================================================

-- 1. Pastikan ekstensi pgcrypto aktif
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Tambahkan kolom is_active di public.profiles jika belum ada
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
    END IF;
END $$;

-- 3. Update nilai NULL pada is_active menjadi TRUE untuk data lama
UPDATE public.profiles
SET is_active = TRUE
WHERE is_active IS NULL;

-- 4. DROP FUNCTION lama jika ada
DROP FUNCTION IF EXISTS public.admin_soft_delete_user(UUID);

-- 5. Buat fungsi RPC public.admin_soft_delete_user
CREATE OR REPLACE FUNCTION public.admin_soft_delete_user(
    target_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    -- Validasi target_user_id
    IF target_user_id IS NULL THEN
        RAISE EXCEPTION 'ID pengguna tidak boleh kosong.';
    END IF;

    -- Proteksi diri: Admin tidak dapat menghapus akunnya sendiri
    IF auth.uid() IS NOT NULL AND target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Admin tidak dapat menghapus akunnya sendiri.';
    END IF;

    -- Periksa apakah user ada di public.profiles
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = target_user_id) THEN
        RAISE EXCEPTION 'Pengguna tidak ditemukan.';
    END IF;

    -- Update is_active = FALSE di public.profiles secara aman (tangani jika updated_at belum ada)
    BEGIN
        UPDATE public.profiles
        SET is_active = FALSE,
            updated_at = now()
        WHERE id = target_user_id;
    EXCEPTION WHEN OTHERS THEN
        UPDATE public.profiles
        SET is_active = FALSE
        WHERE id = target_user_id;
    END;

    -- Update raw_user_meta_data di auth.users secara aman
    BEGIN
        UPDATE auth.users
        SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('is_active', false),
            updated_at = now()
        WHERE id = target_user_id;
    EXCEPTION WHEN OTHERS THEN
        UPDATE auth.users
        SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('is_active', false)
        WHERE id = target_user_id;
    END;

    -- Kembalikan status berhasil
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Pengguna berhasil dinonaktifkan.',
        'user_id', target_user_id
    );
END;
$$;

-- 6. Trigger Otomatis: Sinkronkan perubahan is_active di public.profiles ke auth.users secara otomatis
CREATE OR REPLACE FUNCTION public.sync_profile_is_active_to_auth()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    UPDATE auth.users
    SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('is_active', NEW.is_active),
        updated_at = now()
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_profile_is_active ON public.profiles;
CREATE TRIGGER trg_sync_profile_is_active
AFTER UPDATE OF is_active ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_profile_is_active_to_auth();

-- 7. Sinkronkan semua nilai is_active saat ini dari public.profiles ke auth.users
UPDATE auth.users u
SET raw_user_meta_data = COALESCE(u.raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('is_active', p.is_active)
FROM public.profiles p
WHERE u.id = p.id;

-- 8. Hak akses EXECUTE ke role authenticated, service_role, anon
GRANT EXECUTE ON FUNCTION public.admin_soft_delete_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_soft_delete_user(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_soft_delete_user(UUID) TO anon;

-- 9. Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
