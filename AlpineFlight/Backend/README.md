# Starflight accounts: deployment required

The native client and backend definitions are prepared. The owner has created
Supabase project `yzjzkwcwysstqptcrjvs`, and its URL and public publishable key
are configured in the app. The cloud-save schema, private bucket, owner-only
policies, revision-checked save function and account-deletion function are deployed.
Email confirmation is enabled and the minimum password length is set to 12.
**Email delivery still needs setup.** The live dashboard checked on 7 November 2026
has no custom SMTP connected. New-player registration needs a sender; the built-in
service restricts recipient addresses and sending rate. The client now supports the
default confirmation link: confirm in the email, then return to Starflight and sign in.
Code entry is optional when a custom confirmation email includes a code. Do not label
live sign-up or cross-device sync verified until real email delivery is tested.
Offline device progress stays local.

Live database checks passed via `supabase/verify_isolation.sql`: owner save and
revision update, stale revision rejection, cross-user row and blob isolation,
cross-user write rejection, and private bucket/anonymous privilege checks. All
fixtures were rolled back, including both temporary test identities. Anonymous
REST reads are denied (401). The deployed delete endpoint rejects both missing
and invalid bearer tokens (401); actual signed-in account deletion is untested.

## Set up the project you own

1. Create a Supabase account and a dedicated project at https://supabase.com/dashboard.
   Choose a region suitable for your players. Keep the database password private.
2. Run `supabase/schema.sql` in the project's SQL Editor. This creates a private
   save bucket, per-user row policies, and optimistic concurrency control.
3. In Authentication, enable Email/password, leave email confirmation **on**, and
   set minimum password length to at least 12. Configure SMTP for players outside
   your Supabase project team; the built-in mail service is restricted and rate limited.
4. The default **Confirm signup** email link works with the guided account screen.
   In Authentication → URL Configuration, the Site URL and exact allowed redirect are
   `starflight://hangar` (saved and verified on 7 November 2026). This registered app
   link opens Starflight after confirmation; the player then signs in. The redirect
   never accepts tokens or changes the account by itself. Older emails can retain
   their old localhost redirect; request a fresh confirmation email after this change.
   Alternatively,
   custom SMTP can send `{{ .Token }}` and the player can expand “Use an email link or code”.
   Password recovery accepts the default reset link: copy the link without opening
   it and paste it into the recovery form. The client verifies its token with the
   configured project, then updates the password. Already opened or expired links
   require a new email. Custom recovery emails containing `{{ .Token }}` also work.
5. Deploy `supabase/functions/delete-account/index.ts` as `delete-account` using
   Supabase's Edge Function editor or CLI. Use the included `supabase/config.toml`:
   this project's ES256 tokens are incompatible with the legacy gateway verifier.
   The handler itself verifies every user bearer token with Auth `getUser` before
   accessing admin operations; never remove that check. Supabase supplies the
   server environment variables. The function verifies the
   user, deletes their private files, then deletes their account. Never copy its
   service-role key into the app or send it in chat.
6. Send Codex the **Project URL** and **publishable key** (or legacy `anon` key).
   Both are public client configuration. Put these in
   `AlpineFlight/Resources/Info.plist` under `StarflightAccountURL` and
   `StarflightAccountPublicKey`. Rebuild and install the same configuration on all devices.

## User flow

Settings → Starflight account → Create account → enter email and a 12-character password →
open the email confirmation link → return and choose “I’ve confirmed — sign in”.
The screen also supports resending confirmation and optional emailed codes.
On the first device, Check online save → Save device progress online. On the
second device, sign in to the same Starflight account → Check online save →
Load online progress. Return to base before transfers. The app keeps a complete
local backup under Documents/AccountSaveBackups before replacing a device save.

The payload includes the credit wallet (and reward receipts), unlocks, blueprints,
homes/interior state, checkpoints, pilot logbook, selected craft/region, custom
level recipes and imported USDZ files. Device controls, calibration, graphics,
permissions, password and session credentials are not part of a save. Max imported
library size is 32 MiB; max encoded save is 48 MiB. Files over this size fail clearly
without replacing either save. Sessions are stored in device-only Keychain.

After choosing a save, returning to base auto-uploads changes. Also use Save device
progress online after shopping/editing before switching devices. No mid-flight
position is resumed; the selected region starts at its safe spawn. No balances
are added together. A revision mismatch refuses an outdated upload and asks the
player to check and choose again. Offline errors leave local progress intact.

Uploaded blobs are immutable and older revisions are retained. Monitor storage
usage and implement retention for unreferenced revisions before public release.
The account deletion function removes all of that account's blobs. Local backups
remain on the device. Publish your privacy policy before public distribution.

## Remaining live acceptance checks (pending email setup)

- Repeat ownership checks through real authenticated REST/storage sessions;
  transaction-based database policy checks passed, actual file download is untested.
- Signup confirmation, incorrect code, sign-in, refresh, sign-out, password recovery.
- Earn credits/unlock a craft/edit a home on A, upload, load on B; verify balances,
  receipts, layouts, history and imported models. Reopen both apps to verify persistence.
- Modify A and B offline, upload A, then attempt stale upload B: conflict required.
- Restore on B while A is playing: no automatic replacement of an active flight.
- Delete an account: both cloud row and every storage object must be gone; the
  other account and local device progress must be unaffected.

Native tests use isolated defaults/directories and mocked HTTP; they do not prove
server policies or real email delivery. Do not label cross-device sync verified
until these live checks pass against the deployed service.

Primary references:
https://supabase.com/docs/guides/getting-started/tutorials/with-swift
https://supabase.com/docs/guides/auth/auth-email-templates
https://supabase.com/docs/guides/auth/auth-smtp
