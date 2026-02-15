# ADR: Compose in Separate Window — Not Feasible

## Status: Rejected

## Context
MBOMail wraps mailbox.org (Open-Xchange App Suite v8) in a native macOS WKWebView.
A feature was implemented to open the email compose dialog in a separate native window
(separate WKWebView), allowing users to compose while viewing their inbox.

## Decision
The feature has been removed. OX App Suite's architecture makes it impossible to
reliably render the compose dialog in a separate WKWebView.

## Rationale

### OX App Suite is a Single-Page Application
The compose dialog is not a standalone page — it's a Backbone.js view rendered as a
DOM overlay (`div.io-ox-mail-compose-window`) within the fully-loaded OX application.
It depends on:
- require.js module registry (AMD modules like `io.ox/mail/compose`)
- Backbone.js event bus and global application state
- Session context stored in JavaScript runtime memory

### Session cannot be shared across WKWebView instances
OX uses dual-factor session validation: Session ID (URL parameter) + Session Secret
(cookie). Additionally, OX stores CSRF tokens and app state in `sessionStorage`, which
per the web spec is per-browsing-context (not shared across windows, only copied at
`window.open()` time and then diverges).

Even with shared `WKProcessPool` and `.default()` WKWebsiteDataStore, a new WKWebView
must re-bootstrap the entire OX application. The session validation AJAX call fails
during this bootstrap, producing "Verbindungsfehler" (connection error).

### Approaches considered and rejected
1. **Shared WKProcessPool + cookie store** — OX bootstrap still fails (session mismatch)
2. **window.open() with inherited configuration** — sessionStorage diverges, OX can't
   share in-memory state across JS contexts
3. **Full OX bootstrap in new window** — Would take 5-10 seconds, doubles memory, and
   may still fail due to concurrent session conflicts
4. **OX Mail Compose REST API** — Exists (`/api/mail/compose`) but requires
   reverse-engineering auth, building a complete native compose UI, and mailbox.org
   may not expose all needed endpoints
5. **Native Swift compose UI** — Impractical: would need contacts autocomplete, rich
   text editing, attachment handling, and full API integration

### What works instead
OX's built-in compose overlay works correctly within the main WKWebView. mailto: links
navigate to compose in the main window via the hash fragment
`#!!&app=io.ox/mail&action=compose&to=...`.

## Date: 2026-02-15
