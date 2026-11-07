-- GUDANGAKUN.ID — FULL POSTGRESQL / SUPABASE SCHEMA
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  role TEXT DEFAULT 'worker' CHECK (role IN ('worker', 'admin')),
  available_balance BIGINT DEFAULT 0 CHECK (available_balance >= 0),
  pending_balance BIGINT DEFAULT 0 CHECK (pending_balance >= 0),
  payment_method TEXT DEFAULT 'DANA',
  payment_number TEXT,
  payment_name TEXT,
  is_frozen BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.system_settings (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  kill_switch_open BOOLEAN DEFAULT TRUE,
  announcement TEXT DEFAULT 'Pastikan email pemulihan wajib memakai domain resmi @gudangmail.my.id dan tidak terkait nomor HP.',
  proxy_mode TEXT DEFAULT 'hilink_4g',
  modem_ip_url TEXT DEFAULT 'http://192.168.8.1/api/net/reconnect',
  rotate_every_accounts INTEGER DEFAULT 5,
  proxy_host TEXT DEFAULT 'gw.dataimpulse.com:823',
  proxy_user TEXT DEFAULT 'user_gudang_session',
  bot_concurrency INTEGER DEFAULT 2,
  bot_delay_seconds INTEGER DEFAULT 12,
  bot_max_retries INTEGER DEFAULT 2,
  recovery_domain TEXT DEFAULT '@gudangmail.my.id',
  catch_all_master_email TEXT DEFAULT 'vault.induk@gmail.com',
  auto_batch_penalty BOOLEAN DEFAULT TRUE,
  auto_freeze_worker BOOLEAN DEFAULT TRUE,
  min_withdraw_rp BIGINT DEFAULT 50000,
  supported_methods TEXT DEFAULT 'DANA, OVO, GOPAY, ShopeePay, BCA, SeaBank',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.system_settings (id) VALUES (1) ON CONFLICT DO NOTHING;

CREATE TABLE public.account_types (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  price_per_unit INTEGER NOT NULL,
  hold_duration_hours INTEGER NOT NULL DEFAULT 48,
  required_recovery_domain TEXT DEFAULT '@gudangmail.my.id',
  daily_quota INTEGER DEFAULT 1000,
  quota_used INTEGER DEFAULT 0,
  is_open BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.submission_batches (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  worker_id UUID REFERENCES public.profiles(id) NOT NULL,
  account_type_id INTEGER REFERENCES public.account_types(id) NOT NULL,
  price_locked INTEGER NOT NULL,
  total_submitted INTEGER NOT NULL,
  total_queued INTEGER NOT NULL,
  total_hold INTEGER DEFAULT 0,
  total_approved INTEGER DEFAULT 0,
  total_rejected INTEGER DEFAULT 0,
  batch_status TEXT DEFAULT 'QUEUED' CHECK (batch_status IN ('QUEUED', 'HOLD', 'APPROVED', 'PENALIZED')),
  unlock_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.accounts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  batch_id UUID REFERENCES public.submission_batches(id) ON DELETE CASCADE NOT NULL,
  worker_id UUID REFERENCES public.profiles(id) NOT NULL,
  email TEXT UNIQUE NOT NULL,
  initial_password_enc TEXT NOT NULL,
  new_password_enc TEXT,
  recovery_email TEXT NOT NULL,
  status TEXT DEFAULT 'queued' CHECK (status IN ('queued', 'hold', 'approved', 'rejected', 'pullback_detected')),
  reject_reason TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.withdrawals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  worker_id UUID REFERENCES public.profiles(id) NOT NULL,
  amount BIGINT NOT NULL CHECK (amount > 0),
  payment_info JSONB NOT NULL,
  status TEXT DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'REJECTED')),
  proof_image_url TEXT,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RPC PENALTI KLOTER OTOMATIS (ANTI-PULLBACK)
CREATE OR REPLACE FUNCTION public.penalize_batch_on_pullback(target_batch_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_worker_id UUID;
  v_hold_count INTEGER;
  v_price INTEGER;
  v_deduct BIGINT;
BEGIN
  SELECT worker_id, total_hold, price_locked INTO v_worker_id, v_hold_count, v_price
  FROM public.submission_batches WHERE id = target_batch_id;

  v_deduct := COALESCE(v_hold_count, 0) * COALESCE(v_price, 0);

  UPDATE public.accounts
  SET status = 'rejected', reject_reason = 'Penalti Kloter: Pullback Terdeteksi', updated_at = NOW()
  WHERE batch_id = target_batch_id;

  UPDATE public.submission_batches
  SET batch_status = 'PENALIZED', total_rejected = total_submitted, total_queued = 0, total_hold = 0, total_approved = 0
  WHERE id = target_batch_id;

  UPDATE public.profiles
  SET pending_balance = GREATEST(0, pending_balance - v_deduct), is_frozen = TRUE
  WHERE id = v_worker_id;
END;
$$;
