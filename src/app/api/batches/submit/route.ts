import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { encryptPassword } from '@/lib/crypto-vault';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(req: Request) {
  try {
    const { workerId, accountTypeId, accounts } = await req.json();

    const { data: settings } = await supabase.from('system_settings').select('*').eq('id', 1).single();
    if (!settings?.kill_switch_open) {
      return NextResponse.json({ error: 'Tampungan sedang ditutup oleh Admin' }, { status: 403 });
    }

    const { data: cat } = await supabase.from('account_types').select('*').eq('id', accountTypeId).single();
    if (!cat || !cat.is_open) {
      return NextResponse.json({ error: 'Kategori akun sedang penuh/tutup' }, { status: 400 });
    }

    const { data: batch, error: batchErr } = await supabase
      .from('submission_batches')
      .insert({
        worker_id: workerId,
        account_type_id: accountTypeId,
        price_locked: cat.price_per_unit,
        total_submitted: accounts.length,
        total_queued: accounts.length,
        batch_status: 'QUEUED'
      })
      .select()
      .single();

    if (batchErr) throw batchErr;

    const rows = accounts.map((a: any) => ({
      batch_id: batch.id,
      worker_id: workerId,
      email: a.email.toLowerCase().trim(),
      initial_password_enc: encryptPassword(a.password),
      recovery_email: a.recovery.toLowerCase().trim(),
      status: 'queued'
    }));

    const { error: accErr } = await supabase.from('accounts').insert(rows);
    if (accErr) throw accErr;

    return NextResponse.json({ success: true, batchId: batch.id, totalQueued: rows.length });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
