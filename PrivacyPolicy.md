# Privacy Policy — PubMinder

*Last updated: May 2026*

## Overview

PubMinder is a research-paper reader that aggregates preprints and journal articles from public scientific databases and generates AI summaries. This policy explains what data the app uses and why.

---

## Data We Do Not Collect

PubMinder does **not**:

- Collect or store any personally identifiable information
- Track you across other apps or websites
- Share any data with advertisers or data brokers
- Require account creation or sign-in

---

## Data That Stays on Your Device

The following information is stored **locally on your iPhone only** and never transmitted to us:

| What | Where stored | Why |
|------|-------------|-----|
| Selected subjects and keyword filters | UserDefaults | Remembers your preferences between sessions |
| Saved articles | UserDefaults | Lets you access bookmarked papers offline |
| Onboarding completion flag | UserDefaults | Skips the welcome screens on relaunch |
| Feed size setting | UserDefaults | Controls how many articles to fetch |
| PubMed search queries | UserDefaults | Saves your saved searches |
| Groq API key | iOS Keychain (encrypted) | Authenticates requests to Groq on your behalf |
| NCBI API key | iOS Keychain (encrypted) | Optional higher-rate PubMed access |

API keys are stored in the iOS Keychain — an encrypted, device-bound store that is excluded from iCloud backups.

---

## Third-Party Services

PubMinder connects to the following external services **on your behalf**:

### Scientific Databases (read-only, no authentication)

- **bioRxiv** (Cold Spring Harbor Laboratory) — preprint RSS feeds
- **medRxiv** (Cold Spring Harbor Laboratory / BMJ) — preprint RSS feeds
- **arXiv** (Cornell University) — preprint Atom feeds
- **PubMed / NCBI E-utilities** (National Institutes of Health) — journal article search and abstracts

These are publicly accessible APIs. PubMinder sends only the subject/search queries you configure. No personal information is transmitted.

### AI Summarization

- **Groq** (groq.com) — if you supply a Groq API key, PubMinder sends the text of scientific abstracts to Groq's API to generate 2–3 sentence summaries. Your API key is transmitted to Groq over HTTPS. Groq's own privacy policy applies: [groq.com/privacy](https://groq.com/privacy)

- **Apple Intelligence** (on-device) — if your device supports Apple Intelligence (A17 Pro or later, iOS 26+), PubMinder can summarize abstracts entirely on-device using Apple's Foundation Models framework. No data leaves your device via this path.

---

## Children's Privacy

PubMinder is intended for researchers, students, and anyone interested in scientific literature. It does not knowingly collect data from children under 13.

---

## Changes to This Policy

If this policy changes materially, we will update the "Last updated" date above. Continued use of the app constitutes acceptance of the updated policy.

---

## Contact

Questions about this privacy policy? Email: **genome.school@gmail.com**
