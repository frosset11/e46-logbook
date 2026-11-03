# E46 Logbook

Service history, issues, mileage and the shared Felipe / Bugsy ledger for the 2000 BMW 328Ci (M54 swap).

- `index.html` — the whole site (static, no build step)
- `vercel.json` — hosting headers (also keeps the site out of search engines)
- `supabase/schema.sql` — ledger tables and access rules

## How editing works

Ledger entries and planned purchases live in the Supabase project **e46-logbook**. Anyone with the link can read them; only the emails in the `editors` table (Felipe and Bugsy) can add, change or delete. Sign in from the Ledger page with a one-time email link.

If the database can't be reached, the page falls back to the snapshot of the ledger built into `index.html`.

## One-time setup

1. **Vercel:** Add New → Project → import this repo. Framework preset "Other", no build command, output directory `.`. Deploy.
2. **Supabase sign-in links:** Supabase dashboard → e46-logbook → Authentication → URL Configuration:
   - Site URL: your Vercel URL, e.g. `https://e46-logbook.vercel.app`
   - Redirect URLs: add `https://e46-logbook.vercel.app/**` (and `https://*-frosset11.vercel.app/**` if you want preview deploys to work)

Every push to `main` redeploys automatically.
