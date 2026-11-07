# GudangAkun.id — Full-Stack Account Aggregator (Tema #5 Glassmorphism Nebula)

Paket ini berisi **2 mode penggunaan** yang bisa langsung Anda pilih:

## Cara 1: Langsung Pakai Tanpa Instalasi (Web App Mandiri)
1. Buka folder `standalone-webapp/`
2. Klik 2x file `index.html` di browser Anda, atau upload langsung file `index.html` tersebut ke **Vercel / Netlify / Cloudflare Pages / Hosting cPanel**.
3. Seluruh alur **Worker (Penyetor)** dan **Admin (Pengepul)** beserta menu **Pengaturan Proxy, Kecepatan Bot, Keamanan, Pembayaran, & Manajemen Workers** sudah langsung berfungsi penuh.

## Cara 2: Instalasi Full-Stack Next.js + Supabase + BullMQ Worker
1. Jalankan `supabase/schema.sql` di **Supabase SQL Editor**.
2. Salin `.env.example` menjadi `.env` dan isi kredensial Supabase serta `VAULT_SECRET_KEY`.
3. Install dependencies:
   ```bash
   npm install
   npm run dev
   ```
4. Jalankan Background Worker Bot (Modem 4G HiLink + Playwright):
   ```bash
   npm run worker
   ```

## Cara Push ke GitHub Repository Anda
Klik 2x file `push-to-github.bat` (Windows) atau jalankan `bash push-to-github.sh` (Mac/Linux).
