import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function GET() {
  const { data } = await supabase.from('system_settings').select('*').eq('id', 1).single();
  return NextResponse.json(data);
}

export async function PUT(req: Request) {
  const payload = await req.json();
  const { data, error } = await supabase
    .from('system_settings')
    .update({ ...payload, updated_at: new Date().toISOString() })
    .eq('id', 1)
    .select()
    .single();

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json({ success: true, settings: data });
}
