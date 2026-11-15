# Research notes: Android FCM

Reviewed official Firebase client/receive documentation and Android notification-permission documentation before the reliability changes. Raw downloaded pages are saved alongside these notes.

Verified requirements: runtime notification permission on Android 13+; explicit foreground display; top-level background callback with entry-point pragma; notification SDK background display; token retrieval/refresh; app must be reopened after Android force-stop.

Local inspection: the timer used exactAllowWhileIdle without declaring SCHEDULE_EXACT_ALARM. This can reject scheduling. Added the permission, an optional special-access UI, and inexact fallback. This is a code-level finding, not proof that it was the only cause on the user's phone.

Not verified by documentation alone: actual FCM delivery to the user's installation, OEM power management behavior, timing precision under Doze, availability of Google Play Services, and server-origin automated campaigns. These require device/server tests.
