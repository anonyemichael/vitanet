# UI / UX audit (17 Nov 2026): status of each finding

The audit reviewed `main`. This is where each finding stands on branch `vitanet-ai-tools`.

| # | Finding | Status |
|---|---|---|
| UX-01 | Two colour systems (teal kit vs cyan/violet theme) | **Fixed**: theme secondary + dark nav highlight are teal; old cyan/violet constants deprecated (no screen uses them). Staff portal keeps its own palette on purpose. |
| UX-02 | Home has too many competing sections | **Fixed**: ordered urgent care → symptom check → today's readings and alerts → finding care → setup/shortcuts → wellness reading. |
| UX-03 | "See my result" opens the chat | **Fixed**: "Review my answers" → "Get my result" → triage result page, which offers "Talk it through with the assistant". |
| UX-04 | Onboarding overpromises device data and alerts | **Fixed**: copy says readings come from your own device with permission; contacts who agreed get a text for an unanswered dangerous reading (no location promise). Same fix on profile setup and add-contact. |
| UX-05 | Different breakpoints (800 / 960 / 1000) | **Fixed**: `lib/core/layout/breakpoints.dart` (600 / 840 / 1200) used by patient shell, chat, sign-in, history, resources and the portal. |
| UX-06 | Body area used as a symptom | **Fixed**: body area is its own field; only real symptoms go to the checker. |
| UX-07 | Optional vs required unclear; pain defaults to 5 | **Fixed**: "Optional" labels; pain counts only once the slider is moved; review step with "Change" links. Widget test. |
| UX-08 | Chat composer is dense | Open: needs a design pass on a phone (move advanced tools behind one "+" button, first-use hint). |
| UX-09 | Device looks connected before a reading | **Fixed** (with audit F-06): connected only after a real read; messages name the step that failed. |
| UX-10 | No blood-pressure trends | **Fixed**: top and bottom numbers in health trends. |
| UX-11 | Long profile form, unclear save | **Fixed**: section chips, "unsaved changes / all changes saved", warning before leaving with unsaved edits. |
| UX-12 | Navigation not predictable | **Partly**: rule written in `docs/NAVIGATION.md`; older screens follow it as they are touched. |
| UX-13 | Some screens use other components | Open: hospital directory, visits and pharmacy still use Material `AppBar` / buttons; to move to `VnTopBar` / `VnButton` with a check on a phone. |
| UX-14 | Accessibility not tested | **Partly**: new test `test/large_text_small_screen_test.dart` (360 px phone, 1.5x and 2x text) found and fixed overflows in the assessment, page title bar, list rows and alert card. TalkBack / VoiceOver checks need a real phone (owner to-do). |
| UX-15 | Library could stay stuck loading | **Fixed**: the library service never throws (built-in articles if the backend fails); tests. |
| UX-16 | Pharmacy filters imply certainty | **Fixed**: "Hospitals" / "Clinics" instead of "Emergency room" / "Urgent care"; "Hours not listed" = unknown, not closed; load time shown. |
| UX-17 | Unclear what is current | **Fixed**: "From Health Connect · newest reading 12 min ago"; readings over 12 h old say "Old · 2 d ago". |

Manual test plan T01–T13 (real phones, large text, TalkBack): in `OWNER_TODO.md`.
