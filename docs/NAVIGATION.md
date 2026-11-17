# Navigation rules (UI/UX audit UX-12)

One rule per kind of move, so "Back" always does what people expect:

| Move | Use | Back goes to |
|---|---|---|
| Switch main area (Home, Chat, Resources, Profile tabs) | `context.go('/home')` etc. (tab branch) | stays in the tab; system back leaves the app from a tab root |
| Open a detail page (article, video, hospital, trends, device) | `context.push('/…')` | the page it was opened from |
| Finish a flow (sign-in, onboarding, assessment → result, profile setup) | `context.go('/…')` (replace) | not back into the finished flow |
| Full-screen media (Shorts, video player) | `Navigator.of(context, rootNavigator: true).push(...)` | the page it was opened from |

Every pushed page shows a back button (`VnTopBar` / `VnIconButton` "Back"). The bottom bar hides while scrolling
down and comes back on scroll up or when the keyboard closes; it never hides on a tab's first screen.
New code follows this table; older `MaterialPageRoute` pushes are moved to it when those screens are touched.
