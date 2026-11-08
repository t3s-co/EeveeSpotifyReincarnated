# Inject EeveeSpotify .deb into Pre-built IPA — Setup Guide

This workflow injects a freshly-built EeveeSpotify tweak into **any pre-built IPA** (e.g., a spoti.pw-modified IPA) and re-signs it with your Apple Developer certificate.

## Required GitHub Secrets

Go to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret | Description | Example |
|--------|-------------|---------|
| `SIGNING_CERT_P12_BASE64` | Base64-encoded `.p12` certificate | `base64 -i Certificates.p12 \| pbcopy` |
| `SIGNING_CERT_PASSWORD` | Password for the `.p12` file | `your-p12-password` |
| `SIGNING_TEAM_ID` | Apple Developer Team ID | `ABC123DEFG` |
| `PROVISIONING_PROFILE_BASE64` | *(Optional)* Base64-encoded `.mobileprovision` for ad-hoc distribution | `base64 -i profile.mobileprovision \| pbcopy` |

### How to Generate the Certificate Base64

```bash
# Export your signing certificate from Keychain Access as .p12
# Then encode it:
base64 -i Certificates.p12 | pbcopy
# Paste into SIGNING_CERT_P12_BASE64 secret
```

## Usage

1. Go to **Actions → Inject EeveeSpotify .deb into Pre-built IPA → Run workflow**
2. Choose inputs:
   - **ipa_source**: `url` (direct link) or `artifact` (from another workflow run)
   - **ipa_url**: Direct URL to the pre-built IPA (if using `url`)
   - **artifact_name**: Name of the artifact containing the IPA (if using `artifact`)
   - **branch**: `Master` (only option currently)
   - **upload_method**: `artifacts`, `filebin`, or `both`
3. Click **Run workflow**

## Output

- **EeveeSpotify-deb** artifact: The built `.deb` package
- **Spotify-EeveeInjected-IPA** artifact: Final signed IPA with EeveeSpotify injected
- **filebin.net** link (if selected): Temporary download link

## What Gets Injected

| Component | Source |
|-----------|--------|
| `EeveeSpotify.dylib` | Main tweak logic (Premium unlock, ad blocking) |
| `EeveeSwiftProtobuf.framework` | Required framework for protobuf parsing |
| `EeveeSpotify.bundle` | Resources (icons, configs) |
| `zxPluginsInject.dylib` | Plugin injection helper |

## Re-signing Details

The workflow:
1. Creates a temporary keychain in the runner
2. Imports your `.p12` certificate
3. Generates `entitlements.plist` with:
   - `get-task-allow` (debugging)
   - `application-identifier` (your Team ID + `com.spotify.client`)
   - `disable-library-validation` (allows injected dylibs)
   - `allow-dyld-environment-variables`, `allow-jit`, `allow-unsigned-executable-memory`
4. Re-signs all dylibs/frameworks, then the app bundle
5. Re-packages the IPA

## Notes

- **Bundle ID**: Must remain `com.spotify.client` (reverting custom bundle IDs fixes "Unable to Install" errors)
- **Base IPA**: Should be decrypted (FairPlay removed) — encrypted IPAs won't work
- **spoti.pw IPA**: This workflow expects a pre-built IPA that already has spoti.pw applied. It only injects EeveeSpotify on top.
- **Version**: Auto-read from `control` file, or override with `eevee_version` input