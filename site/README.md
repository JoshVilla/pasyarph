# Pasyar share-link site

The site behind `https://pasyar.pages.dev`, on Cloudflare Pages (free plan).
It does three things:

- **App Links:** `public/.well-known/assetlinks.json` tells Android that links
  on this domain belong to the Pasyar app. Android checks it, then opens
  `/l/…`, `/p/…` and `/join/…` links in the app instead of the browser.
- **"Not installed" pages:** `/l/<loop id>` and `/p/<post id>` show the loop's
  name, distance, ride time, map and store buttons (`functions/`, `lib/`).
  They call Supabase's `link_preview()` signed out, so only public loops and
  posts show details. Club and private links show a short message.
- **Landing page** at `/`.

## One-time setup

1. Log in to Cloudflare (a free account is enough):

   ```
   cd site
   npm install
   npx wrangler login
   ```

2. Create the project. The name becomes the domain, so it must be `pasyar`:

   ```
   npx wrangler pages project create pasyar --production-branch main
   ```

   If Cloudflare says the name is taken, stop and pick another name. That
   name must then replace `pasyar.pages.dev` in `lib/core/links.dart`,
   `android/app/src/main/AndroidManifest.xml` and `lib/features/clubs/club_rules.dart`.

3. Add the Supabase settings (the same values as `env/dev.json`):

   ```
   npx wrangler pages secret put SUPABASE_URL --project-name pasyar
   npx wrangler pages secret put SUPABASE_ANON_KEY --project-name pasyar
   ```

   `MAPTILER_KEY` is optional. The free MapTiler plan has no Static Maps API,
   so leave it unset for now: the page then draws the route as an orange line,
   and loop links in chats show text only. Post links use the post's first
   photo either way.

4. Apply `supabase/migrations/20261024000100_share_links.sql` in the Supabase
   SQL editor.

## Deploy

```
cd site
npm test
npx wrangler pages deploy
```

Then check:

- `https://pasyar.pages.dev/.well-known/assetlinks.json` returns the JSON.
- `https://pasyar.pages.dev/l/<a public loop id>` shows the loop.

## Signing keys in assetlinks.json

Android only opens links in an app signed with a key listed in
`assetlinks.json`. It lists the debug key of the Windows PC (dev and prod
builds are both signed with it for now). Add others as they come up:

- **Another computer** (e.g. the Mac) has its own debug key. Get its
  fingerprint and add it to both entries:

  ```
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
  ```

- **Google Play:** add the "App signing key certificate" SHA-256 from Play
  Console → Test and release → App integrity (Prompt 21).

Redeploy after editing. Android re-checks when the app is installed or updated,
so reinstall the app to test a change.

## Check that Android trusts the links

With the app installed on a phone or emulator:

```
adb shell pm get-app-links com.pasyarph.app.dev
```

`pasyar.pages.dev: verified` means links open in the app. If it says
`legacy_failure` or `1024`, assetlinks.json is missing that build's key, or
the site wasn't deployed yet. To re-check after fixing:

```
adb shell pm verify-app-links --re-verify com.pasyarph.app.dev
```

To open a link without Messenger:

```
adb shell am start -a android.intent.action.VIEW -d "https://pasyar.pages.dev/l/<loop id>"
```

## iOS

`apple-app-site-association` is ready except for the Apple Team ID: replace
`TEAMID` once there's an Apple Developer account, and add the Associated
Domains capability (`applinks:pasyar.pages.dev`) on the Mac.

## Local development

```
cp .dev.vars.example .dev.vars   # then fill in the values
npm run dev                      # http://localhost:8788/l/<loop id>
```
