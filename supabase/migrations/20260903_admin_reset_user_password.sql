-- ==============================================================================
-- Migration: 6-Digit Unique Reset Code & User Management Enhancements
-- Description:
-- 1. Tambah kolom reset_code & updated_at di public.profiles
-- 2. Fungsi admin_set_user_reset_code (Aman dari missing column updated_at)
-- 3. Fungsi verify_reset_code
-- 4. Fungsi complete_reset_password_with_code
-- 5. Fungsi admin_create_user
-- ==============================================================================

-- 1. Pastikan ekstensi pgcrypto aktif
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Tambahkan kolom yang diperlukan di public.profiles jika belum ada
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS reset_code VARCHAR(10);
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT FALSE;
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS password_changed BOOLEAN DEFAULT TRUE;
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
    END IF;
END $$;

-- 3. PERBAIKI AKUN YANG SUDAH TERLANJUR DIBUAT (Hilangkan NULL pada token GoTrue)
UPDATE auth.users
SET 
    confirmation_token = COALESCE(confirmation_token, ''),
    recovery_token = COALESCE(recovery_token, ''),
    email_change = COALESCE(email_change, ''),
    email_change_token_new = COALESCE(email_change_token_new, ''),
    email_change_token_current = COALESCE(email_change_token_current, ''),
    phone_change = COALESCE(phone_change, ''),
    phone_change_token = COALESCE(phone_change_token, ''),
    reauthentication_token = COALESCE(reauthentication_token, '')
WHERE confirmation_token IS NULL 
   OR recovery_token IS NULL 
   OR email_change IS NULL 
   OR email_change_token_new IS NULL;

-- 4. Pastikan semua user memiliki entri auth.identities
INSERT INTO auth.identities (
    id,
    user_id,
    provider,
    provider_id,
    identity_data,
    last_sign_in_at,
    created_at,
    updated_at
)
SELECT 
    gen_random_uuid(),
    u.id,
    'email',
    u.id::text,
    jsonb_build_object('sub', u.id::text, 'email', u.email),
    now(),
    now(),
    now()
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM auth.identities i WHERE i.user_id = u.id AND i.provider = 'email'
);

-- 5. DROP FUNCTION lama jika ada
DROP FUNCTION IF EXISTS public.admin_set_user_reset_code(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_reset_user_password(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.verify_reset_code(TEXT);
DROP FUNCTION IF EXISTS public.complete_reset_password_with_code(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_create_user(TEXT, TEXT, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS public.admin_create_user(TEXT, TEXT, TEXT);

-- 6. Fungsi Admin Menyimpan Kode Reset 6-Digit ke User (Aman tanpa asumsi kolom updated_at)
CREATE OR REPLACE FUNCTION public.admin_set_user_reset_code(
    target_email TEXT,
    code TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id UUID;
    v_clean_code TEXT := UPPER(TRIM(code));
BEGIN
    IF target_email IS NULL OR TRIM(target_email) = '' THEN
        RAISE EXCEPTION 'Email pengguna tidak boleh kosong.';
    END IF;

    IF v_clean_code IS NULL OR LENGTH(v_clean_code) < 4 THEN
        RAISE EXCEPTION 'Kode reset tidak valid.';
    END IF;

    SELECT id INTO v_user_id
    FROM auth.users
    WHERE LOWER(email) = LOWER(TRIM(target_email));

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Pengguna dengan email "%" tidak ditemukan.', target_email;
    END IF;

    -- Update kode reset di public.profiles secara aman
    BEGIN
        UPDATE public.profiles
        SET reset_code = v_clean_code,
            must_change_password = true
        WHERE id = v_user_id;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- Update metadata di auth.users
    UPDATE auth.users
    SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || 
            jsonb_build_object(
                'must_change_password', true,
                'reset_by_admin', true,
                'reset_code', v_clean_code
            ),
        updated_at = now()
    WHERE id = v_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_user_reset_code(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_reset_code(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_user_reset_code(TEXT, TEXT) TO anon;

-- Tetap sediakan admin_reset_user_password untuk kompatibilitas
CREATE OR REPLACE FUNCTION public.admin_reset_user_password(
    target_email TEXT,
    new_password TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    PERFORM public.admin_set_user_reset_code(target_email, new_password);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reset_user_password(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_password(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_password(TEXT, TEXT) TO anon;

-- 7. Fungsi Verifikasi Kode Unik 6-Digit (Tahap 1 Lupa Password)
CREATE OR REPLACE FUNCTION public.verify_reset_code(
    input_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_clean_code TEXT := UPPER(TRIM(input_code));
    v_user RECORD;
BEGIN
    IF v_clean_code IS NULL OR LENGTH(v_clean_code) = 0 THEN
        RAISE EXCEPTION 'Kode unik wajib diisi.';
    END IF;

    SELECT id, username, full_name, email INTO v_user
    FROM public.profiles
    WHERE UPPER(TRIM(reset_code)) = v_clean_code
      AND reset_code IS NOT NULL
      AND TRIM(reset_code) <> ''
    LIMIT 1;

    IF v_user.id IS NULL THEN
        RAISE EXCEPTION 'Kode unik tidak ditemukan atau tidak valid. Silakan hubungi Admin Anda.';
    END IF;

    RETURN jsonb_build_object(
        'valid', true,
        'user_id', v_user.id,
        'username', v_user.username,
        'full_name', v_user.full_name,
        'email_masked', CONCAT(LEFT(v_user.email, 2), '***@', SPLIT_PART(v_user.email, '@', 2))
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_reset_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_reset_code(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.verify_reset_code(TEXT) TO anon;

-- 8. Fungsi Simpan Password Baru Menggunakan Kode 6-Digit (Tahap 2 Lupa Password)
CREATE OR REPLACE FUNCTION public.complete_reset_password_with_code(
    input_code TEXT,
    new_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_clean_code TEXT := UPPER(TRIM(input_code));
    v_user_id UUID;
BEGIN
    IF v_clean_code IS NULL OR LENGTH(v_clean_code) = 0 THEN
        RAISE EXCEPTION 'Kode unik tidak boleh kosong.';
    END IF;

    IF new_password IS NULL OR LENGTH(TRIM(new_password)) < 6 THEN
        RAISE EXCEPTION 'Password baru minimal harus 6 karakter.';
    END IF;

    SELECT id INTO v_user_id
    FROM public.profiles
    WHERE UPPER(TRIM(reset_code)) = v_clean_code
      AND reset_code IS NOT NULL
      AND TRIM(reset_code) <> ''
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Kode unik tidak ditemukan atau sudah kedaluwarsa.';
    END IF;

    -- 8.1 Update password di auth.users & hapus metadata reset
    UPDATE auth.users
    SET encrypted_password = crypt(new_password, gen_salt('bf')),
        raw_user_meta_data = (COALESCE(raw_user_meta_data, '{}'::jsonb) - 'reset_code') || 
            jsonb_build_object(
                'must_change_password', false,
                'reset_by_admin', false,
                'password_changed', true
            ),
        updated_at = now()
    WHERE id = v_user_id;

    -- 8.2 Hapus reset_code dari public.profiles secara aman
    BEGIN
        UPDATE public.profiles
        SET reset_code = NULL,
            must_change_password = false,
            password_changed = true
        WHERE id = v_user_id;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Password berhasil diperbarui.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_reset_password_with_code(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_reset_password_with_code(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_reset_password_with_code(TEXT, TEXT) TO anon;

-- 9. Pembuatan User Baru oleh Admin (Wajib Onboarding Saat Login Pertama)
CREATE OR REPLACE FUNCTION public.admin_create_user(
    new_email TEXT,
    new_password TEXT,
    new_full_name TEXT,
    is_admin_flag BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id UUID := gen_random_uuid();
    v_encrypted_pw TEXT;
    v_username TEXT;
BEGIN
    IF new_email IS NULL OR TRIM(new_email) = '' THEN
        RAISE EXCEPTION 'Email pengguna tidak boleh kosong.';
    END IF;

    IF new_password IS NULL OR LENGTH(TRIM(new_password)) < 6 THEN
        RAISE EXCEPTION 'Password minimal 6 karakter.';
    END IF;

    v_encrypted_pw := crypt(new_password, gen_salt('bf'));
    v_username := split_part(TRIM(new_email), '@', 1);

    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token,
        email_change_token_new,
        email_change,
        email_change_token_current,
        phone_change,
        phone_change_token,
        reauthentication_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        v_user_id,
        'authenticated',
        'authenticated',
        TRIM(new_email),
        v_encrypted_pw,
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object(
            'full_name', TRIM(new_full_name),
            'username', v_username,
            'is_admin', is_admin_flag,
            'must_change_password', true,
            'reset_by_admin', false,
            'password_changed', false,
            'is_first_login', true
        ),
        now(),
        now(),
        '', '', '', '', '', '', '', ''
    );

    INSERT INTO auth.identities (
        id,
        user_id,
        provider,
        provider_id,
        identity_data,
        last_sign_in_at,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        v_user_id,
        'email',
        v_user_id::text,
        jsonb_build_object('sub', v_user_id::text, 'email', TRIM(new_email)),
        now(),
        now(),
        now()
    );

    BEGIN
        INSERT INTO public.profiles (
            id,
            username,
            full_name,
            email,
            is_admin,
            must_change_password,
            password_changed
        ) VALUES (
            v_user_id,
            v_username,
            TRIM(new_full_name),
            TRIM(new_email),
            is_admin_flag,
            true,
            false
        )
        ON CONFLICT (id) DO UPDATE
        SET 
            username = EXCLUDED.username,
            full_name = EXCLUDED.full_name,
            is_admin = EXCLUDED.is_admin,
            must_change_password = true,
            password_changed = false;
    EXCEPTION WHEN OTHERS THEN
        BEGIN
            INSERT INTO public.profiles (id, username, full_name, email, is_admin)
            VALUES (v_user_id, v_username, TRIM(new_full_name), TRIM(new_email), is_admin_flag)
            ON CONFLICT (id) DO UPDATE
            SET username = EXCLUDED.username, full_name = EXCLUDED.full_name, is_admin = EXCLUDED.is_admin;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END;

    RETURN jsonb_build_object(
        'id', v_user_id,
        'username', v_username,
        'email', TRIM(new_email)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_user(TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_user(TEXT, TEXT, TEXT, BOOLEAN) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_create_user(TEXT, TEXT, TEXT, BOOLEAN) TO anon;

-- 10. Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
