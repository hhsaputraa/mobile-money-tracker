-- ==============================================================================
-- Migration: Standarisasi Zona Waktu Asia/Jakarta (WIB, UTC+7)
-- Description:
-- Mengatur timezone default pada level database, roles, dan tabel savings_transactions
-- ke Asia/Jakarta sehingga semua timestamp otomatis tersimpan dan dikueri dalam WIB.
-- ==============================================================================

-- 1. Atur timezone database postgres ke Asia/Jakarta
ALTER DATABASE postgres SET timezone TO 'Asia/Jakarta';

-- 2. Atur timezone default untuk seluruh role koneksi Supabase
DO $$
BEGIN
    EXECUTE 'ALTER ROLE postgres SET timezone TO ''Asia/Jakarta''';
    EXECUTE 'ALTER ROLE authenticated SET timezone TO ''Asia/Jakarta''';
    EXECUTE 'ALTER ROLE anon SET timezone TO ''Asia/Jakarta''';
    EXECUTE 'ALTER ROLE service_role SET timezone TO ''Asia/Jakarta''';
EXCEPTION WHEN OTHERS THEN
    -- Lanjutkan jika ada role yang diatur oleh managed Supabase
    NULL;
END $$;

-- 3. Pastikan kolom waktu pada savings_transactions menggunakan default waktu Asia/Jakarta
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'savings_transactions' 
          AND column_name = 'transaction_date'
    ) THEN
        ALTER TABLE public.savings_transactions 
        ALTER COLUMN transaction_date SET DEFAULT now();
    END IF;
END $$;

-- 4. Reload schema PostgREST
NOTIFY pgrst, 'reload schema';
