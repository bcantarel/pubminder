# PubMinder — App Store Submission Checklist

Everything you need to do to submit PubMinder 1.0 to the App Store.
Code changes from Session 3 are already applied — the steps below are actions you take in Xcode, App Store Connect, or externally.

---

## Step 1 — Add PrivacyInfo.xcprivacy to the Xcode Target

Apple requires a privacy manifest file in the app bundle. The file was created at `PubMinder/PrivacyInfo.xcprivacy` but it must be added to the Xcode target manually:

1. Open `PubMinder.xcodeproj` in Xcode
2. In the Project Navigator, find `PubMinder/PrivacyInfo.xcprivacy`
   - If it's not listed: File → Add Files → select `PubMinder/PrivacyInfo.xcprivacy`
3. In the file inspector (right panel), make sure the **Target Membership** checkbox for **PubMinder** is ticked
4. Build the app (⌘B) — no errors expected

---

## Step 2 — Add KeychainHelper.swift to the Xcode Target

Similarly, `PubMinder/KeychainHelper.swift` was created and needs to be in the target:

1. In the Project Navigator, find `PubMinder/KeychainHelper.swift`
   - If it's not listed: File → Add Files → select `KeychainHelper.swift`
2. Make sure the **PubMinder** target checkbox is ticked
3. Build (⌘B) — verify it compiles without errors

---

## Step 3 — Fix the Bundle Identifier

The current bundle ID is `bcantarel.PubMinder`. Apple prefers reverse-DNS format. If you haven't already registered it, change it to something like `com.bcantarel.pubminder`:

1. Click the blue **PubMinder** project icon in the navigator
2. Select the **PubMinder** target → **Signing & Capabilities**
3. Change **Bundle Identifier** to `com.bcantarel.pubminder` (all lowercase)
4. Do the same for PubMinderTests and PubMinderUITests targets

> Note: if you've already created a Bundle ID in App Store Connect, keep it consistent with what's registered there.

---

## Step 4 — Confirm Signing & Capabilities

1. Under **Signing & Capabilities**, ensure:
   - **Automatically manage signing** is ON
   - **Team** is set to your Apple Developer account
2. Your Apple Developer Program membership must be active ($99/year)

---

## Step 5 — Archive the App

1. Set the scheme to **Any iOS Device (arm64)** — not a simulator
2. Product → **Archive**
3. Wait for the archive to complete; the Organizer window will open

---

## Step 6 — Validate & Upload to App Store Connect

1. In the Organizer, select the archive → **Distribute App**
2. Choose **App Store Connect** → **Upload**
3. Follow the prompts; let Xcode upload the build

---

## Step 7 — Host Your Privacy Policy

App Store Connect requires a publicly accessible Privacy Policy URL. Options:

**Option A — GitHub Pages (free, fast)**
1. Create a public GitHub repo (e.g. `pubminder-privacy`)
2. Add a file called `index.html` or `privacy.md` with the content from `PrivacyPolicy.md`
3. Enable GitHub Pages (Settings → Pages → branch: main, folder: root)
4. Your URL will be: `https://yourgithubusername.github.io/pubminder-privacy`

**Option B — Any web host or even a Google Doc**
- Export `PrivacyPolicy.md` as a public Google Doc and use the sharing URL

---

## Step 8 — Create the App Store Listing in App Store Connect

Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → "+" → New App.

### Required fields

| Field | Suggested value |
|-------|----------------|
| **Name** | PubMinder |
| **Subtitle** | AI Research Feed |
| **Bundle ID** | com.bcantarel.pubminder |
| **SKU** | pubminder-ios-1 |
| **Primary Language** | English (U.S.) |
| **Category** | Reference (primary) / Education (secondary) |
| **Age Rating** | 4+ (no concerning content) |
| **Privacy Policy URL** | Your hosted URL from Step 7 |
| **Support URL** | Your GitHub or email link |

### Description (copy-paste ready)

```
PubMinder is an AI-powered research feed for scientists, students, and curious minds. It aggregates the latest preprints and journal articles from bioRxiv, medRxiv, arXiv, and PubMed — then summarizes each one in 2–3 plain-English sentences using Apple Intelligence (on-device) or Groq's free AI.

WHAT IT DOES
• Fetches the newest papers from the subjects you care about
• Summarizes every abstract automatically — no reading walls of text
• Lets you save and share papers with one tap
• Supports keyword filtering so only relevant papers reach your feed

SOURCES INCLUDED
• bioRxiv — biology and life sciences preprints
• medRxiv — medical and clinical preprints
• arXiv — physics, mathematics, and computer science preprints
• PubMed — peer-reviewed journal articles via NCBI E-utilities

AI SUMMARIZATION
On Apple Intelligence-capable devices (A17 Pro, A18, or M-series, iOS 26+), summaries run entirely on-device — no internet, no API key needed. On other devices, PubMinder uses Groq's free cloud AI. A free Groq API key takes about 2 minutes to set up at console.groq.com.

PRIVACY
PubMinder does not collect personal data, require an account, or track you. API keys are stored in the iOS Keychain, not in plain text. See the full privacy policy for details.
```

### Keywords (100 character limit, comma-separated)

```
research,papers,preprints,pubmed,arxiv,biorxiv,science,AI,summarize,journal,academic,feed
```

### What's New (Version 1.0)

```
First release.
```

---

## Step 9 — Screenshots

Apple requires at least one screenshot for each device size you support. Minimum required:
- **6.9" iPhone** (iPhone 16 Pro Max) — 1320 × 2868 px
- **6.3" iPhone** (iPhone 16 Pro) — 1206 × 2622 px

Suggested screens to capture:
1. Summary tab with a few articles loaded (shows the feed + source badges)
2. Article card expanded to show the AI summary
3. Settings — subjects selected
4. Onboarding — Welcome page

Use Xcode's Simulator (iPhone 16 Pro Max target) to take clean screenshots: Device → Take Screenshot, or ⌘S in the Simulator.

---

## Step 10 — Submit for Review

1. Select your uploaded build in App Store Connect
2. Fill in Export Compliance (answer No to encryption questions — no custom encryption)
3. Fill in the Content Rights section
4. Complete the App Privacy questionnaire:
   - **Data Not Collected** — select this (PubMinder collects no user data)
5. Click **Submit for Review**

Review typically takes 24–48 hours for a first submission.

---

## Known Issues to Fix Before Submission (Optional)

These won't cause rejection but are worth cleaning up:

- **`ListOfThings.swift`** — old prototype file, not connected to the app. Safe to delete from the Xcode target (right-click → Delete → Move to Trash).
- **`FeatuePage.swift` filename typo** — the file is named "FeatuePage" (missing 'r'). The struct inside is correctly named `SavedPage` and works fine. You can rename the file in Xcode by right-clicking it → Rename, but make sure to update the Xcode project reference.

---

## Summary of Code Changes Applied (Session 3)

| File | Change |
|------|--------|
| `KeychainHelper.swift` | NEW — secure Keychain read/write/delete/migrate utility |
| `PrivacyInfo.xcprivacy` | NEW — required Apple privacy manifest |
| `fetchData.swift` | `groqAPIKey` now reads from Keychain instead of UserDefaults |
| `SettingsPage.swift` | Groq + NCBI keys use `@State` + Keychain (auto-migrates from UserDefaults) |
| `OnboardingView.swift` | Groq key uses `@State` + Keychain (auto-migrates from UserDefaults) |
| `PrivacyPolicy.md` | NEW — privacy policy text ready to host |
