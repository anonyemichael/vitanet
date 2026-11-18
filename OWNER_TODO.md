# VitaNet: things only you can do

Everything below needs your accounts, your phone, your money decision or your judgement, so Claude could not do
it. Work top to bottom; tick the boxes as you go. The same list is in both repositories
(`vitanet/OWNER_TODO.md` and `vitanet-model/docs/OWNER_TODO.md`).

Never paste a key into a chat or commit it. Keys go only in the server's `vitanet-backend/.env` file (or your
hosting's "environment variables" page), then restart the backend.

To make a long random string (for the "secret" settings):
`python -c "import secrets; print(secrets.token_urlsafe(32))"`

---

## 1. Security first (10 minutes)

- [ ] **Replace the Africa's Talking API key.** The old key is still in the `vitanet` repository's git history,
      so anyone who sees the repo can use it. In Africa's Talking: Settings → API Key → generate a new one.
      The old one stops working. Put the new one in `.env` as `AT_API_KEY` (step 3).
- [ ] **Check the live server is in production mode.** In the server's `.env`: `ENVIRONMENT=production` and no
      `DEV_BYPASS_AUTH=true` line (that switch turns sign-in checks off; it cannot work in production mode).
- [ ] **Make yourself portal admin:** `BOOTSTRAP_ADMIN_EMAILS=you@example.com` (your sign-in email, verified).

## 2. A permanent server address (audit F-09)

- [ ] The app's default backend address is a temporary Cloudflare tunnel
      (`lib/core/network/backend.dart`), which will stop working one day. Get a fixed address: your hosting's
      URL or a domain you own (e.g. `api.vitanet.app`).
- [ ] Then either tell Claude the address (it changes the default) or build with
      `flutter build apk --dart-define=BACKEND_BASE_URL=https://your-address/`.
- [ ] Set the same address on the server: `PUBLIC_BASE_URL=https://your-address` (links in invite emails).
- [ ] If the web app runs on another domain, add it: `ALLOWED_ORIGINS=https://your-web-app-domain`.

## 3. Free keys for the new features (server `.env`)

| Setting | What it turns on | Where to get it | Cost |
|---|---|---|---|
| `YOUTUBE_API_KEY` | Real, fresh videos on the Clips / Videos page | console.cloud.google.com → new project → enable "YouTube Data API v3" → Credentials → API key → restrict it to that API | Free |
| `PEXELS_API_KEY` | A photo of its own for every library article | pexels.com/api → sign up → your key is shown | Free |
| `RESEND_API_KEY` + `EMAIL_FROM` | Care-circle invite emails, alert emails when a contact has no phone | resend.com → API Keys. Add and verify your domain (Domains), then `EMAIL_FROM=VitaNet <alerts@yourdomain>`. Without a verified domain it can only email YOU. | Free tier |
| `TAVILY_API_KEY` (or `GOOGLE_API_KEY` + `GOOGLE_CSE_ID`) | The assistant's web-search tool | tavily.com (or Google Programmable Search) | Free tier |

Check after a restart: `https://your-address/videos/status` shows `"serving": "youtube"`;
`/library/status` shows about 180 articles.

## 4. SMS line and SMS alerts (Africa's Talking, costs money per SMS)

- [ ] Decide a monthly SMS budget (every reply and every alert text costs a little).
- [ ] In `.env`: `AT_USERNAME` (your app's username, not "sandbox"), `AT_API_KEY` (the new key from step 1),
      `AT_SHORTCODE` (your short code / sender id), `SMS_WEBHOOK_TOKEN` and `SMS_HASH_SECRET` (two different
      long random strings).
- [ ] In Africa's Talking → SMS → Inbox callback URL:
      `https://your-address/sms/inbound?token=<your SMS_WEBHOOK_TOKEN>`
- [ ] Test: text the short code; `https://your-address/sms/health` shows `"sms_configured": true`.
- [ ] Optional: `SMS_MAX_PER_HOUR` (default 15 replies per number per hour), `ALERT_ESCALATION_MINUTES`
      (default 10: minutes before an unanswered urgent alert is sent to the care circle).

## 5. Where the VitaNet model will run (decision + money)

- [ ] The trained model needs a GPU server to answer chats. Until it has one, the chat replies "the assistant
      is offline" (danger-sign warnings, triage, hospitals, videos, library, alerts all still work).
      Decide where: a rented GPU (paid), or a smaller model on a cheaper machine. Ask Claude for options and
      costs first; nothing is rented without your yes.
- [ ] When it runs: `AI_BASE_URL=http://<model-server>:8000/v1`, `AI_MODEL=vitanet-27b`, `AI_API_KEY=<if set>`,
      and the same for the hospital portal: `PORTAL_AI_URL`, `PORTAL_AI_MODEL`, `PORTAL_AI_KEY`.

## 6. Test the app on your phone (branch `vitanet-ai-tools`)

`git fetch && git checkout vitanet-ai-tools && flutter pub get && flutter run`

- [ ] **Watch:** Devices → Connect / Sync now. Readings appear on Home and the message says how many were read
      and saved. Disconnect → readings disappear and stay gone after reopening the app.
- [ ] **Health alerts:** an alert shows on top of every screen with I'm OK / Find hospital / Call 112.
- [ ] **Videos:** Clips feed plays fast; Shorts swipe straight to the next clip; Up next starts quickly.
- [ ] **Library:** real articles, topic chips, search "typhoid", "Read the original" link works.
- [ ] **Assessment:** finish the wizard; if the quick check fails it says so (never a fake "self-care").
- [ ] **Profile:** edit and save; add a care-circle contact by phone (they get an SMS invite once SMS is set up).
- [ ] Note anything odd and tell Claude. When happy, merge the pull requests on GitHub (open the link →
      "Files changed" to look through it → "Merge pull request" → "Confirm merge"):
  - [x] App: https://github.com/anonyemichael/vitanet/pull/1 (merged 17 Nov; still test on your phone)
  - [x] Model: https://github.com/anonyemichael/vitanet-model/pull/2 (merged 17 Nov)
      After merging, on your laptop: `git checkout main && git pull`.

## 7. Twi (you are the native speaker)

- [x] **Mark the Twi check PDF** (done 17 Nov: 0 of 40 machine translations were Good, you chose "Neither",
      so VitaNet's Twi will be written by you, not by a computer).
- [ ] **Translate 147 short sentences + the 12 test openings** in one sheet:
      `vitanet-model/docs/review/VitaNet_Twi_Translate_v1.pdf` (PDF, numbered cards; sent in chat 18 Nov) or the same
      sheet as `twi_fill_in_v1.csv`. Answer by number in chat ("12: …"), or write on a print-out and send photos.
      **Easiest:** it is also in your Google Drive as the Google Sheet "VitaNet Twi – sentences to translate":
      type the Twi in the **twi** column (works in the Google Sheets phone app) and tell Claude when done; Claude
      reads it from Drive. About 2–3 hours; you can stop and go on later.
  1. Google Drive → New → File upload → pick the file → open it with Google Sheets (or open it in Excel).
  2. Write the Twi in the **twi** column only. Do not change the id or english columns.
  3. Write it the way a Ghanaian would really say or type it, not word for word.
  4. "he/she", "him/her": Twi uses one word for both, so write it once.
  5. Keep numbers exactly (112, 193, ages, days). A question stays a question (ends with ?).
     Keep **[SIGN]** where it is: a danger sign is put in there.
  6. Rows marked "TEST ONLY" are the 12 test conversations. They are only for checking VitaNet, never for training.
  7. Typing ɛ and ɔ: on a phone, Gboard → Settings → Languages → add "Twi". If that is hard, write 3 for ɛ and
     c for ɔ (texting style) and say so: the program converts them and shows every change.
  8. File → Download → Comma-separated values (.csv), and send the file to Claude in chat.
  Cost: free. These become VitaNet's Twi danger-sign training data and the Twi test.
- [ ] **Rate 40 rows of the Ghana NLP Twi data** (you chose on 18 Nov to use this non-commercial data). Sheet:
      `vitanet-model/docs/review/VitaNet_Twi_Rate_40.pdf` (sent in chat 18 Nov; 10 rows from each source). Reply in chat
      by card number, e.g. "1 G, 2 S, 3 W" (G = Good, S = Small mistakes, W = Wrong). Or fill the **rating** column of the Google Sheet "VitaNet Twi –
      rate 40 rows" in your Google Drive and tell Claude. A source with many "Wrong" is left out.
      Remember: while this data is in the model, VitaNet must stay free (no paid version, no paid hospital portal).

## 8. Clinical reviewer (your cousin)

- [ ] Review pack: `vitanet-model/docs/review/VitaNet_Clinical_Review_Pack_v1.1.pdf` (rules, sample
      conversations, test cases, safety-layer danger signs). Corrections and sign-off.
- [ ] New since the pack, please check:
  - Fixed danger limits for health alerts: `DANGER_LIMITS` in `vitanet-backend/app/services/health_alert_service.py`
    (e.g. oxygen 91% or less = urgent).
  - Extra triage rules: `vitanet-backend/app/services/ml_service.py` (pain 8+/10, 14+ days, risk factors, fever
    with stiff neck or confusion).
  - The symptom checker over-triages: "headache" alone and "dizziness" alone come out **urgent** (its built-in
    condition list). Which conditions should be urgent?
  - Danger-sign wording in `vitanet-backend/app/services/safety/safety_rules.yaml`.
- [ ] **Trained model's answers (18 Nov), please check:** for a suspected stroke it said "Please do not let her
      sleep; we need to check her now" (is that advice right, or should it be removed?), and for a month-long cough
      it suggested a malaria test (is that sensible in Ghana, or should it only mention TB testing?). Replies are in
      `vitanet-model/experiments/experiment_log.md`, EXP-008 quick eval v2.
- [ ] Help write or check a bigger test set: at least 50 cases, 15 of them red flags.

## 9. Small clean-ups (whenever)

- [ ] The app's own `.env` may hold `UNSPLASH_ACCESS_KEY`, `PIXABAY_API_KEY`, `PEXELS_API_KEY`
      (`lib/data/services/media_library_service.dart`, not used by any screen). Keys inside an app can be copied
      out of it: leave them empty; photos now come from the server.
- [ ] Kaggle: nothing to do. Training runs from GitHub with the repository secrets you already set.

## 10. Usability checks on real phones (UI/UX audit, needs people and devices)

Claude tested layouts automatically (small phone, large text), but these need a real phone and real people:

- [ ] **Low-end Android phone**, branch `vitanet-ai-tools`, go through: fresh install → onboarding → sign-in →
      profile setup → symptom assessment → result → chat → find a hospital. Note anything slow, confusing or cut off.
- [ ] **Large text:** phone Settings → Display → Font size at the largest; repeat the journey above.
- [ ] **TalkBack** (Android: Settings → Accessibility → TalkBack): can you reach and hear every button on Home,
      the assessment and the alert banner?
- [ ] **No internet** (airplane mode): open Home, Library, Videos, Chat: each should say what is wrong and offer a retry.
- [ ] **Location off / denied:** Pharmacy and Hospitals should still let you search by place name.
- [ ] **Two or three first-time users** (family or friends): give them the phone, ask them to "check a symptom"
      without help, and note where they get stuck. Do the same with one hospital staff member on the portal.
- [ ] Check that pharmacy and hospital listings near you in Ghana are right (names, phone numbers, hours).

## 11. Host the backend on Google Cloud Run (your Firebase project) — needs your decision and 4 clicks

Claude prepared everything that is free: a deploy workflow (`.github/workflows/deploy-backend.yml`) that builds
the backend, puts it on Cloud Run in the Firebase project `vitanet-62e40` (region europe-west1), and sets a free
every-minute job for health alerts. It does nothing until the steps below are done.

- [ ] **Approve Claude's workflows once.** GitHub asks the owner the first time a workflow comes from the Claude app.
      GitHub → vitanet repo → Actions → the "deploy-backend" run marked "Action required" → "Approve and run"
      (until the secrets below exist it only prints "Not set up yet" and deploys nothing). Then Actions →
      "check-secrets" → "Run workflow" → branch main → "Run workflow" (it lists secret NAMES only, never values).
- [ ] **Decide on the Blaze plan (money).** Cloud Run needs the Firebase project on the pay-as-you-go "Blaze"
      plan with a card. A small app like this stays inside the free tier (2 million requests a month), so expect
      about $0–2 a month; the workflow caps it at 2 server copies. Firebase console → ⚙ → Usage and billing →
      Modify plan → Blaze, then set a **budget alert of $5** (Google Cloud console → Billing → Budgets & alerts).
- [ ] **Free database:** neon.tech → sign up (no card) → create project "vitanet" (region Frankfurt) → copy the
      connection string (starts with `postgresql://`).
- [ ] **Service account key:** console.cloud.google.com → project vitanet-62e40 → IAM & Admin → Service Accounts →
      Create "github-deploy" → roles: Cloud Run Admin, Cloud Build Editor, Artifact Registry Administrator,
      Service Account User, Storage Admin, Cloud Scheduler Admin → Keys → Add key → JSON (a file downloads).
- [ ] **Put them in GitHub** (vitanet repo → Settings → Secrets and variables → Actions → New repository secret):
      `GCP_SA_KEY` = the whole JSON file's text, `DATABASE_URL` = the Neon string, `TICK_TOKEN` = a long random
      string. The other server keys from sections 3–5 can go here too (same names); the workflow passes them on.
      Then delete the downloaded JSON file from your laptop.
- [ ] **Run it:** Actions → deploy-backend → Run workflow. The log ends with "Backend address: https://…".
      Tell Claude that address: it becomes the app's permanent server address (audit F-09).
- [ ] **Firebase project names differ:** `.firebaserc` says `vitanet-prod-gh`, the app signs in with
      `vitanet-62e40`. Tell Claude which one is right (the deploy uses `vitanet-62e40`).
