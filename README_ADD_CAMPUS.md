# README — Adding Campuses to CampusSell Firestore

## Overview

This document explains how to add new campuses (universities/colleges) to the
CampusSell app database. All campuses are stored in the Firestore `campuses`
collection and appear in the app's campus selection screen.

---

## Files Involved

```
campus_mart/
├── universities.json      ← your campus data goes here
├── upload.js              ← script that uploads to Firestore
├── serviceAccountKey.json ← Firebase credentials (never commit to git)
└── README_ADD_CAMPUS.md   ← this file
```

---

## One-Time Setup (Already Done)

If you are setting this up on a new machine, do these steps once:

### 1. Install Node.js
Download from https://nodejs.org and install.

### 2. Install Firebase Admin SDK
Run this in the project root:
```bash
npm install firebase-admin
```

### 3. Get Service Account Key
```
Firebase Console
→ Project Settings (gear icon ⚙️)
→ Service accounts tab
→ Generate new private key
→ Download JSON file
→ Rename it to: serviceAccountKey.json
→ Place it in your project root folder
```

> ⚠️ IMPORTANT: Never upload serviceAccountKey.json to GitHub or share it.
> It is already listed in .gitignore.

---

## Data Format

Each campus entry in `universities.json` must follow this format:

```json
[
  {
    "university": "Full University Name",
    "state": "State Name",
    "district": "District Name"
  }
]
```

### Example

```json
[
  {"university":"University of Delhi","state":"Delhi","district":"Delhi"},
  {"university":"Jawaharlal Nehru University","state":"Delhi","district":"New Delhi"},
  {"university":"Jamia Millia Islamia","state":"Delhi","district":"New Delhi"},
  {"university":"IIT Delhi","state":"Delhi","district":"New Delhi"},
  {"university":"IIT Bombay","state":"Maharashtra","district":"Mumbai"},
  {"university":"Anna University","state":"Tamil Nadu","district":"Chennai"}
]
```

---

## How to Add New Campuses

### Step 1 — Open `universities.json`

Add your new entries to the existing list. Do NOT delete old entries unless
you want to remove them from the app.

```json
[
  {"university":"University of Delhi","state":"Delhi","district":"Delhi"},
  {"university":"Jawaharlal Nehru University","state":"Delhi","district":"New Delhi"},

  // ← Add new entries here
  {"university":"New University Name","state":"State","district":"District"}
]
```

### Step 2 — Run the Upload Script

```bash
node upload.js
```

### Step 3 — Check Output

You should see:
```
✅ Done! Total processed: 6 campuses
```

### Step 4 — Verify in Firebase Console

```
Firebase Console
→ Firestore Database
→ campuses collection
→ Confirm new documents are there
```

---

## How the Upload Script Works

The script uses the **university name as the Firestore document ID**.
This means:

| Situation | What Happens |
|---|---|
| University already exists in Firestore | Overwritten with same data — no duplicate |
| New university added to JSON | New document created in Firestore |
| University removed from JSON | Old document stays in Firestore (not deleted) |

So it is always safe to run `node upload.js` — it will never create duplicates.

---

## How It Appears in the App

After uploading, campuses appear immediately in the app's search on the
Campus Selection screen. Users can search by:
- Campus name
- District
- State

---

## Removing a Campus

If you need to remove a campus from the app:

### Option A — Firebase Console (Easy)
```
Firebase Console
→ Firestore
→ campuses collection
→ Find the document
→ Click the three dots menu
→ Delete document
```

### Option B — Script
Add this to `upload.js` and run once:
```js
await db.collection('campuses').doc('document_id_here').delete();
```

---

## Handling Campus Requests from Users

When a user submits a campus request from the app, it goes to the
`campus_requests` collection in Firestore with `verified: false`.

### Review Process

```
Firebase Console
→ Firestore
→ campus_requests collection
→ Review pending requests (verified: false)
```

### Adding a Verified Campus

1. Copy the `name`, `state`, `district` from the request
2. Add it to `universities.json`
3. Run `node upload.js`
4. Update the request document: set `verified: true`

The campus is now live in the app instantly.

---

## Firestore Structure

Each document in the `campuses` collection looks like:

```
campuses/
└── university_of_delhi          ← document ID (auto-generated from name)
    ├── name:     "University of Delhi"
    ├── state:    "Delhi"
    └── district: "Delhi"
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Cannot find module 'firebase-admin'` | Run `npm install firebase-admin` |
| `Error: Failed to parse private key` | Re-download serviceAccountKey.json from Firebase Console |
| `PERMISSION_DENIED` | Make sure serviceAccountKey.json is from the correct Firebase project |
| Campus not showing in app | Check spelling matches exactly — search is case-insensitive but data must be correct |
| `universities.json` parse error | Validate JSON at jsonlint.com — check for missing commas or brackets |

---

## Security Reminders

```
✅ serviceAccountKey.json → listed in .gitignore → never commit
✅ universities.json → safe to commit → no sensitive data
✅ upload.js → safe to commit → no sensitive data
✅ README_ADD_CAMPUS.md → safe to commit
```

---

## Quick Reference Card

```
Add new campus:
  1. Open universities.json
  2. Add entry: {"university":"Name","state":"State","district":"District"}
  3. Run: node upload.js
  4. Done ✅

Approve user request:
  1. See campus_requests in Firebase Console
  2. Add to universities.json
  3. Run: node upload.js
  4. Set verified: true on the request
  5. Done ✅
```

---

*Last updated: April 2026 — CampusSell v1.0*
