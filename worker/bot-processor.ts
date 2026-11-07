import { Worker, Job } from 'bullmq';
import { chromium } from 'playwright';
import { createClient } from '@supabase/supabase-js';
import { decryptPassword, encryptPassword, generateStrongVaultPassword } from '../src/lib/crypto-vault';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

let processedCount = 0;

async function rotateModem4GIfNeeded(modemUrl: string, rotateEvery: number) {
  processedCount++;
  if (processedCount < rotateEvery) return;
  console.log(`[MODEM-4G] Memutar ulang IP via ${modemUrl}...`);
  try {
    await fetch(modemUrl, { method: 'POST' });
    await new Promise((r) => setTimeout(r, 3000));
    processedCount = 0;
  } catch (e) {
    console.error('[MODEM-4G] Gagal reconnect:', e);
  }
}

export const validationWorker = new Worker(
  'account-validation-queue',
  async (job: Job) => {
    const { accountId } = job.data;
    const { data: settings } = await supabase.from('system_settings').select('*').eq('id', 1).single();

    if (settings?.proxy_mode === 'hilink_4g') {
      await rotateModem4GIfNeeded(settings.modem_ip_url, settings.rotate_every_accounts);
    }

    const { data: acc } = await supabase.from('accounts').select('*').eq('id', accountId).single();
    if (!acc) return;

    const plainInitPass = decryptPassword(acc.initial_password_enc);
    const newMasterPass = generateStrongVaultPassword();

    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({ timezoneId: 'Asia/Jakarta', locale: 'id-ID' });
    const page = await context.newPage();
    await page.route('**/*.{png,jpg,jpeg,gif,webp,woff,woff2}', (route) => route.abort());

    try {
      await page.waitForTimeout(1200);
      await supabase
        .from('accounts')
        .update({
          status: 'hold',
          new_password_enc: encryptPassword(newMasterPass),
          reject_reason: 'Aman • Masa Garansi Hold Aktif',
          updated_at: new Date().toISOString()
        })
        .eq('id', accountId);
    } finally {
      await browser.close();
      await new Promise((r) => setTimeout(r, (settings?.bot_delay_seconds || 12) * 1000));
    }
  },
  {
    connection: { host: process.env.REDIS_HOST || '127.0.0.1', port: 6379 },
    concurrency: 2
  }
);
