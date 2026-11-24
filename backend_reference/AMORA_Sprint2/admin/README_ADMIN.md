# Founder admin console

Run from `backend_reference/AMORA_Sprint2/admin`:

```bash
cp .env.example .env.local
npm install
npm run build
npm run dev
```

Only set the public Supabase URL and anon key in `.env.local`. Never put the service-role key in the browser app. Admin pages check `app_metadata.role` for navigation, but all sensitive access is independently enforced by Supabase RLS and admin-only SQL functions.
