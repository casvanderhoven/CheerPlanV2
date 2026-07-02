# Releasing CheerPlan to TestFlight

Releases run entirely in GitHub Actions (`.github/workflows/release.yml`) using
Xcode **cloud signing** — no certificates on your machine, no keychains, no
fastlane. The workflow archives the app, signs it with credentials Apple manages
server-side, and uploads straight to App Store Connect.

Three things only the Apple account holder can do, once. After that a release
is one click.

## One-time setup (~15 minutes)

### 1. Apple Developer Program

Enroll at <https://developer.apple.com/programs/enroll/> ($99/year). TestFlight
is unavailable without it.

### 2. Create the app record in App Store Connect

1. <https://appstoreconnect.apple.com> → **Apps** → **+** → **New App**.
2. Platform **iOS**, any name (e.g. "CheerPlan"), language, and bundle ID
   **`com.cheerplan.app`**.
   - If the bundle ID isn't offered in the dropdown, register it first at
     <https://developer.apple.com/account/resources/identifiers> (Identifiers →
     **+** → App IDs → App, explicit bundle ID `com.cheerplan.app`).
   - If Apple says the bundle ID is taken by another team, change
     `bundleIdPrefix` and both `PRODUCT_BUNDLE_IDENTIFIER`s in
     `App/project.yml` (e.g. `com.yourname.cheerplan`), commit, and use that ID
     here instead.
3. SKU can be anything (e.g. `cheerplan`).

The widget extension's bundle ID (`com.cheerplan.app.widgets`) does **not**
need its own app record; the first workflow run registers both App IDs
automatically.

### 3. Create an App Store Connect API key and add the repo secrets

1. App Store Connect → **Users and Access** → **Integrations** →
   **App Store Connect API** → Team Keys → **+**.
2. Name it (e.g. "CheerPlan CI"), role **App Manager**. Generate, then
   **download the `.p8` file** (single chance) and note the **Key ID** and the
   page's **Issuer ID**.
3. Your Team ID is at <https://developer.apple.com/account> under Membership
   details (10 characters).
4. GitHub repo → **Settings** → **Secrets and variables** → **Actions** →
   **New repository secret**, four times:

   | Secret name | Value |
   |---|---|
   | `APPLE_TEAM_ID` | your 10-character Team ID |
   | `APP_STORE_CONNECT_KEY_ID` | the API key's Key ID |
   | `APP_STORE_CONNECT_ISSUER_ID` | the Issuer ID |
   | `APP_STORE_CONNECT_KEY_P8` | the full text of the `.p8` file, pasted as-is (including the BEGIN/END lines) |

## Each release (one click)

GitHub → **Actions** → **TestFlight** → **Run workflow** → pick the branch →
**Run**. The build number is the workflow run number, so every run increments
automatically; the marketing version comes from `MARKETING_VERSION` in
`App/project.yml`.

When the run is green, the build appears in App Store Connect → your app →
**TestFlight** after Apple's processing (usually 5–30 minutes). Add yourself
under **Internal Testing** (create a group, add your Apple ID) — internal
testers need no beta review. Install via the TestFlight app on your phone.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Run fails at "Check required secrets" | Add the four secrets from step 3 — names must match exactly. |
| `ITMS-90022` / "no app record" on upload | Step 2 wasn't completed, or the bundle ID in the app record differs from `App/project.yml`. |
| "Cloud signing permission error" / `Unable to authenticate` | The API key's role is too low — recreate it with **App Manager** (Developer is not enough for cloud signing + upload). |
| Bundle ID already in use by another team | Change the IDs in `App/project.yml` (see step 2) and create the app record with the new ID. |
| First run is slow at the archive step | Cloud signing is creating the distribution certificate and profiles — one-time cost. |
| Build never appears in TestFlight | Check App Store Connect for an email about a processing rejection (most are icon/plist issues — both are handled in this repo). |
