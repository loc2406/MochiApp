# Mochii AI gateway

Requires Node.js 22. No npm install is needed.

```sh
node --test server.test.mjs
node --env-file=/path/to/private/gateway.env server.mjs
```

Copy `.env.example` to a private path and fill in the Supabase values and
`GEMINI_API_KEY` first. The Gemini key stays on the gateway; never put it in the
Flutter app or the APK. The default models are `gemini-3.8-flash` and
`gemini-3.5-flash-lite`; override them with `GEMINI_PRIMARY_MODEL` and
`GEMINI_FALLBACK_MODEL` if needed.
Browser origins are controlled by `ALLOWED_ORIGINS` (comma-separated). The
default includes production and Flutter Chrome on `127.0.0.1:8600` or
`localhost:8600`. If you set `ALLOWED_ORIGINS` yourself, include the exact
Chrome origin and restart the gateway. For example:

```sh
ALLOWED_ORIGINS=https://bendocs.tailc1f51b.ts.net,http://127.0.0.1:8600
```

The app chooses the gateway with `--dart-define=MOCHI_AI_GATEWAY=...`.
Without that define, a loopback web preview calls the same-origin `/mochi-ai`
path, which `05-operations/preview.py` relays server-side (no CORS involved).
Gateway binds to loopback only. Use a TLS reverse proxy for external access.
See `03-documentation/03-CAU-HINH-DICH-VU.md` in the handover root.

For internal APK testing from Windows without a custom domain, follow
`../../05-operations/HUONG-DAN-TEST-AI-APK.md` (temporary Cloudflare Quick
Tunnel + `flutter run`).
