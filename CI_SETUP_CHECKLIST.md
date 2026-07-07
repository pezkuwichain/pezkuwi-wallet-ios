# iOS Release Pipeline — Setup Checklist

This fork inherited a working, CI-driven build/sign/publish pipeline from `novasamatech/nova-wallet-ios`
(fastlane + GitHub Actions macOS runners — no local Mac needed to build or publish). Bundle identifiers
and repo references have been updated to our own (`io.pezkuwichain.wallet`), but the pipeline can't run
end-to-end until the accounts below exist and their secrets are set.

## 1. Apple Developer Program (blocking, longest lead time)

- Enroll as an **Organization** account (not Individual) — required for crypto/wallet apps under Apple's
  review guidelines, and needed to publish under the "PezkuwiChain" name rather than a personal name.
- Requires a **D-U-N-S Number** for the legal entity — apply via Apple's D-U-N-S lookup (free, via D&B).
  Can take 5–30 business days. Start this first.
- Cost: $99/year.
- Once approved, note down: **Team ID** (alphanumeric, e.g. `AB12CD34EF`) and **ITC Team ID** (numeric,
  found in App Store Connect > Users and Access > Membership).

## 2. App Store Connect — app record

- Register the bundle IDs (App IDs) under the new Apple Developer account:
  `io.pezkuwichain.wallet`, `io.pezkuwichain.wallet.dev`, `io.pezkuwichain.wallet.staging`,
  `io.pezkuwichain.wallet.notificationServiceExtension`, `io.pezkuwichain.wallet.dev.NovaPushNotificationServiceExtension`,
  `io.pezkuwichain.wallet.staging.NovaPushNotificationServiceExtension`.
- Create the app record in App Store Connect (this generates the **ASC App ID**, a numeric ID —
  needed for `ASC_APP_ID` secret below).
- Generate an **App Store Connect API Key** (Users and Access > Keys > App Store Connect API) —
  this alone lets CI do signing/upload headlessly, no Xcode GUI needed. Note **Key ID**, **Issuer ID**,
  and download the `.p8` key file (base64-encode it for the secret below).

## 3. fastlane match — certificate storage

- A private repo already exists for this: `pezkuwichain/match-security-pezkuwi-wallet-ios`
  (empty, ready — `fastlane/Matchfile` already points to it).
- Once the Apple account + API key exist, run `fastlane update_signing_data` (via the
  `update_signing_data.yml` workflow, or locally on any Mac/CI runner) to generate and push
  certificates/profiles into that repo. After that, `prepare_code_signing` (used by every build lane)
  will just read them — no manual cert handling ever again.

## 4. GitHub Secrets to set on `pezkuwichain/pezkuwi-wallet-ios`

| Secret | Where it comes from |
|---|---|
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect API issuer ID |
| `ASC_KEY_BASE64` | The `.p8` key file, base64-encoded |
| `ASC_APP_ID` | Numeric App Store Connect app ID (after app record is created) |
| `KEYCHAIN_PASSWORD` | Any random string — used only to lock/unlock the CI keychain |
| `MATCH_GIT_BASIC_AUTHORIZATION` | A GitHub PAT (base64 `user:token`) with access to the match-security repo above |
| `WRITE_SECRET_PAT` | GitHub PAT with repo-secret write access (used by `bump_version.yml`) |
| `FIREBASE_APP_ID`, `CREDENTIAL_FILE_CONTENT`, `FIREBASE_GROUPS` | Only needed if we want Firebase App Distribution for internal testing (optional — TestFlight alone is enough to ship) |

**Note on Scaleway:** the inherited `pull_request.yml` / `push_develop.yml` / `update_signing_data.yml`
workflows fetch `MATCH_GIT_BASIC_AUTHORIZATION` and `KEYCHAIN_PASSWORD` from **Scaleway Secret Manager**
(Nova's own preference), which means an extra Scaleway account + 4 more secrets
(`SCW_ACCESS_KEY`/`SCW_SECRET_KEY`/`SCW_DEFAULT_PROJECT_ID`/`SCW_DEFAULT_ORGANIZATION_ID`) would be needed
to use them as-is. **This is optional** — the simplest path is to swap those two lookups in
`.github/actions/install/action.yml` for plain `${{ secrets.KEYCHAIN_PASSWORD }}` /
`${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}` GitHub Secrets instead, removing the Scaleway dependency
entirely. Left as-is for now since it doesn't block anything else — flag if you want it simplified.

## 5. Suggested order of operations

1. File the D-U-N-S application today (longest wait).
2. While waiting: review/finish the rebrand pass (colors, icons, app name) in this repo — no Apple
   account needed for that part, it's just code/assets.
3. Once Apple Developer Organization is approved: create the App Store Connect app record + API key,
   fill in `fastlane/Appfile` placeholders and the GitHub Secrets above.
4. Run `update_signing_data` once to populate the match repo with real certificates.
5. Push to `develop` → CI builds + distributes automatically (Firebase, if configured) or run
   `distribute_testflight` for a TestFlight beta — this is the first real, Mac-free build/sign
   verification of everything done in this pass.
6. TestFlight beta first, then submit for full App Store review.
