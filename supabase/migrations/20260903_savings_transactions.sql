-- ==============================================================================
-- Migration: Savings Transactions & Dashboard Overview
-- Description:
-- 1. Buat tabel public.savings_transactions
-- 2. Index performa untuk user_id dan transaction_date
-- 3. Row Level Security (RLS): Nasabah hanya baca miliknya, Admin akses penuh CRUD
-- 4. Fungsi RPC get_my_savings_summary() dan get_admin_savings_summary()
-- 5. Hak akses dan reload schema PostgREST
-- ==============================================================================

-- 1. Buat tabel savings_transactions jika belum ada
CREATE TABLE IF NOT EXISTS public.savings_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    type VARCHAR(20) NOT NULL DEFAULT 'deposit',
    description TEXT,
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Index performa query riwayat per nasabah dan urutan waktu
CREATE INDEX IF NOT EXISTS idx_savings_user_date ON public.savings_transactions (user_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_savings_date ON public.savings_transactions (transaction_date DESC);

-- 3. Aktifkan Row Level Security (RLS)
ALTER TABLE public.savings_transactions ENABLE ROW LEVEL SECURITY;

-- 3.1 Drop policy lama jika ada untuk idempotensi
DROP POLICY IF EXISTS "savings_select_policy" ON public.savings_transactions;
DROP POLICY IF EXISTS "savings_insert_policy" ON public.savings_transactions;
DROP POLICY IF EXISTS "savings_update_policy" ON public.savings_transactions;
DROP POLICY IF EXISTS "savings_delete_policy" ON public.savings_transactions;

-- 3.2 SELECT Policy: Nasabah baca miliknya sendiri, Admin baca semua
CREATE POLICY "savings_select_policy"
ON public.savings_transactions
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND (p.is_admin IS TRUE)
    )
);

-- 3.3 INSERT Policy: Khusus Admin
CREATE POLICY "savings_insert_policy"
ON public.savings_transactions
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND (p.is_admin IS TRUE)
    )
);

-- 3.4 UPDATE Policy: Khusus Admin
CREATE POLICY "savings_update_policy"
ON public.savings_transactions
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND (p.is_admin IS TRUE)
    )
);

-- 3.5 DELETE Policy: Khusus Admin
CREATE POLICY "savings_delete_policy"
ON public.savings_transactions
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND (p.is_admin IS TRUE)
    )
);

-- 4. Fungsi Agregasi Ringkasan untuk Nasabah yang Login (get_my_savings_summary)
CREATE OR REPLACE FUNCTION public.get_my_savings_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_total_balance NUMERIC(15, 2) := 0;
    v_count INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('total_balance', 0, 'total_transactions', 0);
    END IF;

    SELECT 
        COALESCE(SUM(amount), 0),
        COUNT(*)
    INTO v_total_balance, v_count
    FROM public.savings_transactions
    WHERE user_id = v_user_id;

    RETURN jsonb_build_object(
        'total_balance', v_total_balance,
        'total_transactions', v_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_savings_summary() TO authenticated, service_role, anon;

-- 5. Fungsi Agregasi Ringkasan untuk Admin (get_admin_savings_summary)
CREATE OR REPLACE FUNCTION public.get_admin_savings_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_total_pool NUMERIC(15, 2) := 0;
    v_total_count INTEGER := 0;
    v_active_customers INTEGER := 0;
BEGIN
    SELECT COALESCE(SUM(amount), 0), COUNT(*)
    INTO v_total_pool, v_total_count
    FROM public.savings_transactions;

    SELECT COUNT(*)
    INTO v_active_customers
    FROM public.profiles
    WHERE (is_admin IS FALSE OR is_admin IS NULL)
      AND (is_active IS TRUE OR is_active IS NULL);

    RETURN jsonb_build_object(
        'total_savings_pool', v_total_pool,
        'total_transactions_count', v_total_count,
        'active_customers_count', v_active_customers
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_admin_savings_summary() TO authenticated, service_role, anon;

-- 6. Hak akses tabel
GRANT ALL ON TABLE public.savings_transactions TO authenticated;
GRANT ALL ON TABLE public.savings_transactions TO service_role;

-- 7. Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
