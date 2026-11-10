# Wellness implementation status

Reviewed 2026-11-10 against the local source tree.

## Overall assessment

The primary Flutter + FastAPI application is an implemented MVP. It is not yet
production ready. The repository also contains a separate legacy Next.js app;
its presence does not mean it serves the Flutter application.

| Area | Current implementation | Remaining work |
| --- | --- | --- |
| Authentication | Registration, bcrypt passwords, login, access/refresh tokens, logout, account lockout, audit events, database-backed authentication rate limits | Production password policy and trusted-proxy configuration review |
| Session security | Unique token identifiers, atomic refresh rotation, refresh-token digests, inactive-user rejection, password reset revocation, shared Flutter refresh requests | PostgreSQL integration verification and legacy-session rollout |
| Health profile | Authenticated profile read/update and persistent medical fields | Data retention, export/deletion, privacy and access review |
| Patient and doctor dashboards | Real account summaries, patient/doctor signup, private consultation requests/messages, assigned-doctor acceptance/closure, labeled public review previews | Operator approval of doctor accounts; appointments, video, notifications and broader care operations |
| Chat assistant | Persisted sessions/history, profile context, Google Gen AI SDK, schema-constrained responses, visible persistent fallback labels | Confirm model access and verify real AI responses with credentials; expand evaluation |
| Cardiac risk | Prediction endpoint, bundled model loader, mathematical fallback | Model cannot load in the minimal dependency environment because scikit-learn is missing; pandas is also absent from requirements. Model provenance, feature alignment and validation remain unverified. Fallback score must not be treated as a validated probability |
| Specialist recommendations | Rule-based symptom matching and Flutter screen | Broader evaluation and emergency-routing review |
| Hospital search | State search, optional external API, curated fallback records | Verify live API integration and data freshness; location/distance search is not implemented |
| Password reset | SMTP delivery, Flutter request/reset screens, hash-based links, expiry, atomic token consumption, session revocation and request limits | Configure SMTP credentials and verify delivery against the chosen provider |
| Contact | Validation, persistent submissions, reference ID, and database failure handling | Staff inbox UI/notification integration and retention policy |
| Newsletter | Persistent subscription and duplicate handling | Double opt-in, unsubscribe and delivery integration |
| Deployment | Configurable Flutter API URL, backend environment validation, health endpoints | Real hosting, HTTPS domains, credentials, migrations, backups and monitoring |
| Automated checks | Backend suite and new Flutter/FastAPI CI workflow | Frontend verification results below; legacy Next.js checks have not been run |

## Implemented in this pass

- Added `API_BASE_URL` Flutter build configuration while retaining local defaults.
- Added production validation for secret length, secure cookies and explicit HTTPS CORS origins.
- Removed the fixed development JWT secret; unconfigured local instances use a random per-process secret.
- Reduced access-token lifetime to 15 minutes and aligned session lifetime with refresh-token expiry.
- Added unique token IDs to prevent same-second token collisions across logins/refreshes.
- Rejected refresh for inactive users and revoked all sessions when resetting a password.
- Returned HTTP 401 for missing credentials so the Flutter refresh interceptor can handle it.
- Added `/health/live` and database-backed `/health/ready` (503 on database failure).
- Made the Gemini model configurable, validated response fields and limited history retrieval to 10 rows.
- Added environment examples and automated backend/Flutter checks in `.github/workflows/app-checks.yml`.
- Isolated test database initialization from tracked development/test database files.
- Updated voice input to the installed speech package's options API and cleared existing analyzer findings.

## Verification

- Backend: **43 tests passed**, including consultation workflows/roles/revocation, provider diagnostics, concurrent refresh/rate limits, cross-user isolation, refresh replay, repeated login uniqueness,
  inactive-user refresh, password reset revocation, malformed AI response fallback,
  production configuration and readiness failure.
- Gemini tests use mocks. No real model request or clinical accuracy validation was performed.
- Flutter: **21 tests passed** using `flutter test --no-pub`, including patient/doctor dashboards, sample conversation navigation, private-dashboard sign-in, concurrent token refresh, transient failure handling, password recovery, reset deep links and chat source metadata.
- Flutter static analysis: **no issues found** after speech API/lint cleanup.
- Flutter release web build: **passed** with a placeholder hosted API URL; output is
  `frontend/build/web`. This artifact verifies compilation and requires the real API
  URL before deployment. Wasm dry-run compilation also succeeded.
- Flutter dependencies downloaded; plugin setup reported that Windows Developer Mode
  is needed for native plugin symlink support. Tests succeeded without rerunning pub setup.
- Legacy Next.js dependencies/build were not installed or verified. Its config currently
  suppresses TypeScript/lint build errors and places JWT configuration under `env`;
  review that implementation before deploying it.
- CI workflow is included; hosted CI results and deployment have not been verified.

## Local setup

From `backend/`, create a virtual environment, install `requirements.txt`, and copy
`env.example` to `.env`. Configure a persistent random `JWT_SECRET` and an API key
for real AI responses. Confirm `GEMINI_MODEL` is available to that account; the
default retains the existing application value and has not been verified remotely.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements.txt
Copy-Item env.example .env
.\.venv\Scripts\python -m uvicorn app.main:app --host 127.0.0.1 --port 9005
```

In a second terminal:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --web-port 9004
```

For a hosted backend:

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://your-api-host/api
```

Set backend `ENVIRONMENT=production`, a unique secret of at least 32 characters,
`COOKIE_SECURE=true`, and `CORS_ORIGINS` to a JSON array containing the frontend's
HTTPS origin. Set `FRONTEND_URL` to that public HTTPS frontend address. Use an explicit persistent secret for multiple server workers.

## Next implementation priorities

1. Configure and verify SMTP delivery; add a staff interface for persisted contact submissions.
2. Verify the configured Gemini model with real credentials and expand AI response evaluation.
3. Resolve and validate the ML pipeline rather than silently substituting unvalidated scores.
4. Verify authentication hardening on the production database and configure trusted proxy addresses.
5. Add database migrations, retention controls, deployment configuration and backups.
6. Consolidate or explicitly retire the legacy stack and correct contradictory README privacy claims.

Existing edits to `.vscode/settings.json` and `CONTRIBUTING.md` were left intact.

## Second implementation pass: account recovery and contact persistence

Implemented:

- SMTP password-reset delivery using STARTTLS or implicit SSL with certificate
  verification and a configurable timeout. SMTP calls run outside the API event loop.
- Reset links open the Flutter `/#/reset-password` route and safely encode email/token values.
- Forgot-password success responses use identical wording for existing/unknown accounts.
  Missing SMTP configuration or delivery failure returns an actionable 503 instead of
  a simulated success. Raw tokens, email bodies and reset links are not logged.
- Only SHA-256 token digests are stored. Tokens expire after an hour and are consumed
  with a conditional update in the same transaction as password/session changes.
  A failed older email attempt cannot clear a newer request's token.
- Flutter includes a forgot-password link, request screen, password confirmation,
  reset success/error states, incomplete-link handling and a new-link action.
- Contact submissions are committed to `contact_submissions` before success is returned.
  The response includes `submissionId`; storage failures return 503. Submission bodies
  are no longer written to application logs. A staff-facing inbox is not included yet.
- Added mounted checks to avoid updating a disposed contact screen after network calls.

The new contact table is additive and is created by the application's existing
startup table initialization. No existing table schema was changed. Previously
issued reset links using raw stored tokens must be requested again.

### Email setup

Configure these values in `backend/.env` (see `backend/env.example`):

```dotenv
FRONTEND_URL=https://your-frontend-host
SMTP_HOST=smtp.your-provider.example
SMTP_PORT=587
SMTP_FROM_EMAIL=noreply@your-domain.example
SMTP_USERNAME=your-smtp-username
SMTP_PASSWORD=your-smtp-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false
SMTP_TIMEOUT_SECONDS=10
```

For implicit SSL, use your provider's SSL port (commonly 465), set
`SMTP_USE_SSL=true` and `SMTP_USE_TLS=false`. Production requires HTTPS for
`FRONTEND_URL` and encrypted SMTP when SMTP is configured. The frontend URL must
be the public address of the Flutter app, without a query string or fragment.
For local development use `FRONTEND_URL=http://localhost:9004` with a local mail
capture server or your SMTP provider. No test messages have been sent to a live provider.

Verification for this pass: **29 backend tests passed**, **10 Flutter tests passed**,
and **Flutter analysis reported no issues**. SMTP transport, URL encoding and failure
handling were verified with mocks; no real emails were sent. Release compilation
**passed**, including the Wasm dry run. The generated web artifact remains configured
with a placeholder API URL and must be rebuilt with the real backend URL for deployment.

ML pipeline validation remains pending. API rate/session hardening is covered by the fourth pass below.

## Third implementation pass: Gemini migration and fallback visibility

- Replaced `google-generativeai` with `google-genai` (verified locally with version
  2.34.0). The adapter follows the [official Google Gen AI SDK documentation](https://googleapis.github.io/python-genai/).
- Added a provider adapter with a Pydantic response schema, configurable timeout,
  one request attempt and automatic client cleanup. Calls run in a worker thread
  so synchronous provider I/O does not block the API event loop.
- Response status is always explicit: `source` is `gemini` or `local_fallback`;
  `fallbackReason` describes configuration, timeout, empty/invalid response or service
  unavailability without returning provider exception details.
- Stored response source and fallback reason in existing message metadata. No
  database migration is needed for these fields. Historical messages without
  source metadata remain unknown rather than being labeled as Gemini responses.
- Flutter shows **General guidance · AI unavailable** on fallback messages and
  preserves that indication when loading chat history.
- Database response-save failures return an error rather than being disguised as
  an AI outage. Existing medical fallback text is unchanged.
- Added tests for missing credentials, saved source metadata, provider timeout,
  invalid structured output, Flutter history decoding and the visible fallback label.

Preparation: set `GOOGLE_AI_API_KEY` (or an existing supported alias), confirm
`GEMINI_MODEL` is available to the account, and optionally adjust
`GEMINI_TIMEOUT_SECONDS` (default 8). No provider calls were made with real health
data or real credentials. Live model access and output quality remain unverified.

Current verification: **31 backend tests**, **12 Flutter tests**, and clean Flutter
analysis. **Release web compilation passed**, including the Wasm dry run. Build
output uses the placeholder API URL and requires the real URL before deployment.

## Fourth implementation pass: authentication and session hardening

- Authentication endpoints now enforce fixed-window limits in the existing
  `rate_limits` database table. Counters are atomic across workers sharing a database;
  exhausted windows return HTTP 429 with `Retry-After`, and database failures return 503.
  Stale counters are pruned on successful requests.
- Limits per client address: login 10/minute, registration 5/5 minutes, password
  recovery 5/15 minutes, reset attempts 10/15 minutes, refresh/logout 60/minute,
  email checks 20/minute. GET/POST email checks share a counter. Other API routes
  are not covered by this authentication limiter.
- Client addresses come from the ASGI connection. The application does not parse
  forwarded headers. Configure Uvicorn's trusted proxy addresses explicitly when
  deploying behind a proxy; only trust infrastructure that replaces client headers.
  Clients behind the same address share limits. Counter keys hash the address and
  contain no request bodies, email addresses or tokens.
- New sessions store SHA-256 refresh-token digests. Refresh consumes the digest
  with a conditional database update that rechecks session expiry, activity and
  user activity. Exactly one concurrent request can rotate a given token.
  Rotating tokens does not extend the original database session expiry, and the
  refreshed cookie lifetime now reflects that remaining expiry.
- Access authentication also requires the stored session owner to match the JWT
  subject. Tests cover cross-user chat reads, writes, deletion and listing.
- Flutter shares one refresh operation across parallel 401 responses, reuses the
  new access token for delayed failures, and retries each request once while
  preserving its request options. HTTP 429, server outages and retry failures
  preserve saved tokens; refresh rejection with HTTP 401 clears the session.

Rollout: the existing session column already holds a digest without a schema change.
Previously stored raw refresh tokens are deliberately rejected; users of those
sessions must sign in again when their access token expires. Existing raw database
values are not rewritten automatically. Revoke or purge old sessions as part of
deployment to remove those stored credentials.

Verification: **37 backend tests passed** against SQLite, including forced
simultaneous refresh reads (one success, one HTTP 401), eight concurrent limit
requests (exactly three admitted), limit expiry, spoofed-header rejection,
digest storage and cross-user isolation. The two limiter tests also passed after
the final stale-counter cleanup adjustment. **17 Flutter tests passed**, including
parallel/delayed 401 handling, token retention on HTTP 429/503, logout on refresh
rejection and retention after a failed retry. **Flutter analysis found no issues.**
PostgreSQL and hosted proxy behavior have not been exercised. The release web
build documented above is from the earlier pass; it was not rebuilt in this pass.

Remaining priorities: ML model provenance/feature validation, live Gemini and SMTP
verification, contact staff tooling, migrations/retention, deployment/backups and
legacy documentation cleanup. This pass does not make the application production ready.

## Local preview repair (2026-11-10)

- Built a fresh release with the real local API URL and local CanvasKit assets:
  `flutter build web --release --no-pub --no-web-resources-cdn --pwa-strategy=none --dart-define=API_BASE_URL=http://127.0.0.1:9005/api`.
- Replaced the debug server with a static server for `frontend/build/web` on
  port 9004. Review at `http://localhost:9004` while that server is running.
- Added a visible startup indicator, first-frame completion handling, and a retry
  state for initialization errors or timeouts. CanvasKit loads from this server.
- Release compilation and the Wasm dry run passed. Verified the release bundle,
  local JS/Wasm/font assets and backend readiness all return HTTP 200.
- A fresh isolated headless Chrome run rendered the actual landing page, including
  navigation, Login, Try Wellness, Find Specialist and the feature cards. Screenshot:
  `frontend/build/preview.png`. This confirms rendering, not every application flow.

## Patient/doctor dashboards and AI diagnostics (2026-11-10)

- Added a distinct account dashboard instead of opening directly into chat after
  sign-in. Real summaries show consultation counts, profile completion and chat
  history counts from the current account. The existing assistant remains accessible.
- Added separate patient and doctor signup choices. Doctor applications remain
  `doctor_pending` until an operator independently checks credentials and approves
  app access with `backend/manage_doctors.py`. Signup cannot grant doctor privileges.
- Patients can select an approved active doctor and submit a consultation request.
  Both participants can read/send private messages. Only the assigned approved
  doctor can accept/close the consultation. Closed consultations remain readable
  and cannot receive more messages or reopen. Revoked doctors lose access.
- Added additive consultation/message tables, role/participant checks and request
  limits. No patient health profile or AI history is automatically shared with doctors.
- Added labeled sample previews at `/#/review/patient` and `/#/review/doctor`, linked
  from the landing page. Sample conversations are read-only and never access real
  patient data. Private dashboards require sign-in.
- Added a generic AI connection probe on the dashboard and in `backend/check_ai.py`.
  Provider errors now distinguish credentials, access, model availability and quota
  failures without exposing provider exception text.
- Created a local ignored `backend/.env` template with a persistent random JWT
  secret and an empty AI key. Backend restarted with new endpoints. Existing local
  sessions signed with the earlier per-process secret require sign-in again.
- Live AI is **not fixed or verified yet**: `GOOGLE_AI_API_KEY` remains empty.
  The app accurately reports this instead of claiming an active provider.

Verification: **43 backend tests passed**, **21 Flutter tests passed**, **Flutter
analysis found no issues**, and **release compilation/Wasm dry run passed**.
Fresh isolated Chrome runs rendered both compiled dashboard previews; screenshots
are `frontend/build/patient-dashboard.png` and `frontend/build/doctor-dashboard.png`.
Backend readiness and the new compiled bundle return HTTP 200. Role and privacy
workflows were exercised with isolated test accounts; no real doctor was approved
and no real patient messages were sent by these checks.

See [backend/CARE_SETUP.md](backend/CARE_SETUP.md) for local review links, doctor
approval/revocation and provider configuration. Appointments, video calls and
message notifications remain unimplemented; this pass adds asynchronous care messaging.
