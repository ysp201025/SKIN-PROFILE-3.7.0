# 🟩 Supabase Setup Guide — SKIN-PROFILE Real-time Features

This guide enables **Global Chat**, **Voice Messages**, **Voice Chat**, and **Shop** to work across ALL users in real-time — now powered by [Supabase](https://supabase.com) instead of Firebase.

---

## ✅ What's Real-time Now

| Feature | How it works |
|---|---|
| 💬 Global Chat | Supabase Postgres table + Realtime (`postgres_changes`) — everyone sees every message instantly |
| 🎤 Voice Messages | Recorded → Supabase Storage → playable by everyone |
| 📞 Voice Chat | WebRTC mesh + Supabase Realtime **Broadcast** (signaling) & **Presence** (who's in the room) |
| 🛒 Shop / Marketplace | Supabase Postgres table + Realtime — items listed by one user, bought by another |
| 💰 Coins | Synced via a Postgres table + an atomic purchase function — coin balance updates across devices |

---

## Step 1 — Create a Supabase Project

1. Go to **https://supabase.com/dashboard**
2. Click **"New project"**
3. Give it any name (e.g. `skin-profile-app`), pick a database password and region
4. Click **"Create new project"** and wait for it to finish provisioning

---

## Step 2 — Run the Database Schema

1. Inside your project, open **SQL Editor → New query**
2. Open `supabase/schema.sql` from this repo, copy the whole file, and paste it in
3. Click **"Run"**

This single script creates:
- The `users`, `chat_messages`, and `marketplace_items` tables
- Row Level Security policies that allow public read/write (matching the old Firebase "test mode" rules)
- Realtime publication for all three tables
- The `set_user_coins` and `purchase_marketplace_item` Postgres functions (atomic coin transfers — the equivalent of Firebase RTDB's `.transaction()`)
- A public `voice` Storage bucket for voice messages, with public read/upload policies

> The full script is also at `supabase/schema.sql`

---

## Step 3 — Get Your API Keys

1. In your project, go to **Project Settings → API**
2. Copy the **Project URL** and the **anon public** key

---

## Step 4 — Paste the Config into index.html

Open `index.html` and find this block near the top (inside `<script>`):

```js
const supabaseConfig = {
    url: "YOUR_SUPABASE_URL",
    anonKey: "YOUR_SUPABASE_ANON_KEY"
};
```

Replace it with your actual URL and anon key from Step 3.

---

## Step 5 — Deploy to GitHub Pages

1. Push all files to a GitHub repository
2. Go to repo **Settings → Pages**
3. Under **Source**, select **`main` branch → `/root`**
4. Save — GitHub gives you a URL like `https://yourname.github.io/repo-name/`
5. Share that link with everyone! 🎉

---

## 📊 Supabase Free Tier Limits

| Resource | Free Limit |
|---|---|
| Database | 500 MB storage |
| File Storage | 1 GB storage, 2 GB egress/month |
| Realtime | 200 concurrent connections, 2M messages/month |
| Monthly active users | 50,000 |

This is more than enough for hundreds of users.

---

## 🔒 Security Note

The Supabase URL and anon key in `index.html` are **not secret** — they are designed to be public, same as the old Firebase config. Security is enforced by the Row Level Security (RLS) policies set up in `supabase/schema.sql`. You can tighten those policies later if you add real user authentication (e.g. require `auth.uid()` to match the row owner instead of allowing anyone to write).

---

## 🏗️ Architecture Notes (for anyone maintaining this code)

- **Chat & Marketplace**: plain Postgres tables, read via `supabase.from(...).select()` and kept live with `supabase.channel(...).on('postgres_changes', ...)`.
- **Coins**: stored in the `users` table, keyed by the app's local device UID. Purchases go through the `purchase_marketplace_item` Postgres function so the coin deduction, coin credit, and listing removal all happen atomically in one database transaction — this replaces Firebase RTDB's `ref().transaction()`.
- **Voice messages**: uploaded to the public `voice` Storage bucket, then the public URL is saved on the chat message row (same pattern as Firebase Storage's `getDownloadURL()`).
- **Voice chat rooms**: use a Realtime channel per room (`voice-room-<roomId>`) combining:
  - **Broadcast** for WebRTC signaling (offer/answer/ICE candidates) and lightweight mic/speaker state updates — low-latency, not persisted.
  - **Presence** for join/leave detection — it automatically "untracks" a user when their tab closes or connection drops, which is the direct equivalent of Firebase's `onDisconnect()`.

---

## ❓ Troubleshooting

| Problem | Fix |
|---|---|
| "Supabase မ setup မလုပ်ရသေးပါ" warning | Replace `YOUR_SUPABASE_URL` / `YOUR_SUPABASE_ANON_KEY` in `supabaseConfig` |
| Voice chat not connecting | Both users must allow microphone access; try different networks |
| Messages not appearing | Confirm `supabase/schema.sql` ran successfully and the tables are added to the `supabase_realtime` publication |
| Voice messages not uploading | Check the `voice` Storage bucket exists and is public (created automatically by the schema script) |
| "new row violates row-level security policy" errors | Re-run the RLS policy section of `supabase/schema.sql` |
