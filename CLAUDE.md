# Rules for AI assistants working in this repo

- **Anything that needs the owner** (a key or account, a setting on the server, a money decision, a test on their phone, a Twi translation, a clinical review) goes into the to-do list straight away: `OWNER_TODO.md` in the vitanet app repo and `docs/OWNER_TODO.md` in vitanet-model (keep both the same). Write it as a tick box with plain steps (where to click, which setting, what it costs). Tick or remove items once they are done. Also say it in the reply.
- Never put API keys in the app or in the code: they go in the server's `vitanet-backend/.env`. Never ask the owner to paste a key in chat.
- Work on branch `vitanet-ai-tools` (not `main`) unless the owner says otherwise.
