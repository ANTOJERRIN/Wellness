# Patient, doctor and AI setup

The primary app is Flutter plus FastAPI. Open the review previews without an account:

- Patient: `http://localhost:9004/#/review/patient`
- Doctor: `http://localhost:9004/#/review/doctor`

These previews contain labeled sample data and a read-only sample conversation.
They do not grant access to any patient records or simulate a live AI connection.

## Real accounts and consultations

1. Sign up as a patient or doctor. Existing `user` accounts are patient accounts.
2. Doctor registrations start as `doctor_pending`. An operator must independently
   check the doctor's credentials before running this command from `backend/`:

   ```powershell
   .\.venv\Scripts\python manage_doctors.py approve doctor@example.com
   ```

   Use `revoke` in place of `approve` to remove doctor access. This CLI updates app
   access; it does not independently verify professional credentials.
3. Sign in to open the real dashboard. Patients select an approved doctor and send
   a consultation request. Both participants can read and send messages. The
   assigned doctor can accept or close the consultation.
4. Closed consultations remain readable, but cannot receive messages or reopen.
   Refresh the dashboard or conversation to receive the latest changes. Messages
   are asynchronous; appointments, video calls and notifications are not implemented.

Only the patient's submitted request and consultation messages are shared with
the selected doctor. Other health profile fields and AI chat history are not
automatically shared. Users outside the consultation cannot access it.

The additive `consultations` and `consultation_messages` tables are created by
the existing startup initialization. No existing table columns changed.

## Enable live AI

The local backend starts with AI disabled when no key is configured. A configured
key alone is not evidence of a successful provider connection.

1. Edit the ignored `backend/.env` file locally. Set `GOOGLE_AI_API_KEY` to your
   Google AI credential. Keep credentials out of chat and source control.
2. Set `GEMINI_MODEL` to a model your account can use. The current default
   `gemini-3.5-flash` is listed in Google's [official model documentation](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash).
3. From `backend/`, run `.\.venv\Scripts\python check_ai.py`. This sends only a
   generic greeting request and reports a sanitized failure reason or success.
4. Restart FastAPI after editing environment settings. The dashboard's **Check AI
   connection** button also runs a generic probe, limited to three attempts per
   five minutes per user. Provider requests can consume provider quota.

Connection errors distinguish missing configuration, rejected credentials,
denied access, unavailable model, quota limits, timeouts and invalid responses.
No patient data is sent by the connection probe. Actual chat uses the existing
profile/history context when the user sends a message; fallback messages remain
explicitly labeled when the provider is unavailable.
