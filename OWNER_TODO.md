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
- [ ] Note anything odd and tell Claude. When happy: merge `vitanet-ai-tools` into `main` (Claude can open the
      pull request if you ask).

## 7. Twi (you are the native speaker)

- [ ] **Mark the Twi check PDF** (`vitanet-model/docs/review/VitaNet_Twi_Check_v1.pdf`, also sent in chat):
      Good / Small mistakes / Wrong meaning for each A and B, and which is better. A short reply is enough.
- [ ] Then **translate about 150 short template sentences** into Twi (Claude prepares an easy fill-in list once
      your marks are in). These become VitaNet's Twi danger-sign training data.
- [ ] **Write the 12 benchmark openings in Twi** (the test conversations, never trained on), so Twi can be tested.

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
- [ ] Help write or check a bigger test set: at least 50 cases, 15 of them red flags.

## 9. Small clean-ups (whenever)

- [ ] The app's own `.env` may hold `UNSPLASH_ACCESS_KEY`, `PIXABAY_API_KEY`, `PEXELS_API_KEY`
      (`lib/data/services/media_library_service.dart`, not used by any screen). Keys inside an app can be copied
      out of it: leave them empty; photos now come from the server.
- [ ] Kaggle: nothing to do. Training runs from GitHub with the repository secrets you already set.
