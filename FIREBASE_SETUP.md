# 🔥 Firebase Setup Guide — SKIN-PROFILE Real-time Features

This guide enables **Global Chat**, **Voice Messages**, **Voice Chat**, and **Shop** to work across ALL users in real-time.

---

## ✅ What's Real-time Now

| Feature | How it works |
|---|---|
| 💬 Global Chat | Firebase Realtime Database — everyone sees every message instantly |
| 🎤 Voice Messages | Recorded → Firebase Storage → playable by everyone |
| 📞 Voice Chat | WebRTC mesh + Firebase signaling — real multi-user voice rooms |
| 🛒 Shop / Marketplace | Firebase Realtime Database — items listed by one user, bought by another |
| 💰 Coins | Synced via Firebase — coin balance updates across devices |

---

## Step 1 — Create a Firebase Project

1. Go to **https://console.firebase.google.com**
2. Click **"Add project"**
3. Give it any name (e.g. `skin-profile-app`)
4. Disable Google Analytics (optional)
5. Click **"Create project"**

---

## Step 2 — Add a Web App

1. Inside your project, click the **`</>`** (Web) icon
2. Give it a nickname (e.g. `skin-profile-web`)
3. **Do NOT** enable Firebase Hosting (we use GitHub Pages)
4. Click **"Register app"**
5. You'll see a `firebaseConfig` block like this — **copy it**:

```js
const firebaseConfig = {
  apiKey: "AIza...",
  authDomain: "your-project.firebaseapp.com",
  databaseURL: "https://your-project-default-rtdb.firebaseio.com",
  projectId: "your-project",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123...:web:abc..."
};
```

---

## Step 3 — Paste the Config into index.html

Open `index.html` and find this block near the top (inside `<script>`):

```js
const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
    databaseURL: "https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com",
    ...
};
```

Replace it with your actual config from Step 2.

---

## Step 4 — Enable Realtime Database

1. In Firebase Console → **Build → Realtime Database**
2. Click **"Create database"**
3. Choose **"Start in test mode"** → **Enable**
4. Go to **Rules** tab and paste:

```json
{
  "rules": {
    "chat":        { "messages":  { ".read": true, ".write": true } },
    "voiceRooms":  { "$roomId":   { ".read": true, ".write": true } },
    "marketplace": { "items":     { ".read": true, ".write": true } },
    "users":       { "$uid":      { ".read": true, ".write": true } }
  }
}
```

Click **"Publish"**.

> The full rules file is also at `firebase-rules/database.rules.json`

---

## Step 5 — Enable Firebase Storage (for Voice Messages)

1. In Firebase Console → **Build → Storage**
2. Click **"Get started"** → **"Start in test mode"** → **Next → Done**
3. Go to **Rules** tab and paste:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if true;
    }
  }
}
```

Click **"Publish"**.

> The full rules file is also at `firebase-rules/storage.rules`

---

## Step 6 — Deploy to GitHub Pages

1. Push all files to a GitHub repository
2. Go to repo **Settings → Pages**
3. Under **Source**, select **`main` branch → `/root`**
4. Save — GitHub gives you a URL like `https://yourname.github.io/repo-name/`
5. Share that link with everyone! 🎉

---

## 📊 Firebase Free Tier Limits

| Service | Free Limit |
|---|---|
| Realtime Database | 1 GB storage, 10 GB/month transfer |
| Storage | 5 GB storage, 1 GB/day download |
| Realtime connections | 100 simultaneous |

This is more than enough for hundreds of users.

---

## 🔒 Security Note

The Firebase config keys in `index.html` are **not secret** — they are designed to be public. Security is enforced by Firebase Rules (set in Step 4 & 5). You can tighten the rules later to require authentication.

---

## ❓ Troubleshooting

| Problem | Fix |
|---|---|
| "Firebase မ setup မလုပ်ရသေးပါ" warning | Replace `YOUR_API_KEY` etc. in firebaseConfig |
| Voice chat not connecting | Both users must allow microphone access; try different networks |
| Messages not appearing | Check Realtime Database rules are set to `true` |
| Voice messages not uploading | Check Storage rules are set to `true` |
| "Permission denied" errors | Re-check and re-publish Firebase Rules |
