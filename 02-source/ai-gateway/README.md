# Mochii AI gateway

Requires Node.js 22. No npm install is needed.

```sh
node --test server.test.mjs
node --env-file=/path/to/private/gateway.env server.mjs
```

Copy `.env.example` to a private path and fill in values first.
Browser origins are controlled by `ALLOWED_ORIGINS` (comma-separated). The
default is the production origin only; add another origin explicitly when a new
domain or a local preview must call the gateway, for example:

```sh
ALLOWED_ORIGINS=https://bendocs.tailc1f51b.ts.net,http://127.0.0.1:8600
```

The app chooses the gateway with `--dart-define=MOCHI_AI_GATEWAY=...`.
Without that define, a loopback web preview calls the same-origin `/mochi-ai`
path, which `05-operations/preview.py` relays server-side (no CORS involved).
Gateway binds to loopback only. Use a TLS reverse proxy for external access.
See `03-documentation/03-CAU-HINH-DICH-VU.md` in the handover root.
