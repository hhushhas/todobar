# TodoBar

TodoBar is a small macOS menu bar queue for tasks and agent prompts. Capture a title instantly, drag its priority badge to rank it, add a copyable description and tags when useful, optionally set a dated reminder, then cross the task out and move on.

## Repo layout

- `app/macos/sources/todobar` contains the macOS menu bar app.
- `app/macos/tests/todobar-tests` contains the Swift test target.
- `app/macos/assets/branding` contains macOS app icons and menu bar artwork.
- `site/src` contains the TanStack Start marketing site.
- `public` contains static assets served by the marketing site.
- `docs/design` contains design-only HTML previews and reference files.

## Setup

1. Install dependencies:

   ```sh
   pnpm install
   swift package resolve
   ```

2. Create `.env.local` with:

   ```sh
   TODOBAR_CONVEX_URL=https://your-deployment.convex.cloud
   TODOBAR_CLERK_PUBLISHABLE_KEY=pk_test_or_pk_live...
   CLERK_FRONTEND_API_URL=https://your-clerk-frontend-api-url
   ```

3. Configure Convex auth:
   - In Clerk, enable the Convex integration.
   - Set `CLERK_FRONTEND_API_URL` for Convex, then run `pnpm convex:dev`.

4. Run the app during development:

   ```sh
   swift run TodoBar
   ```

The app falls back to a local JSON store until Convex and Clerk keys are present. This build targets macOS 26 because the current Convex Swift binary archive is built against the macOS 26 SDK.

## Build an app bundle

```sh
./scripts/build-app.sh
open dist/TodoBar.app
```

To replace the menu bar app installed in `/Applications` and launch that fresh build:

```sh
pnpm run install:mac
```

## Package a notarized release

The release script creates unsigned local packages by default. To produce a
signed and notarized release, provide your own Developer ID signing identity
and a `notarytool` Keychain profile:

```sh
SIGN_IDENTITY="Developer ID Application: Your Company (TEAMID)" \
NOTARY_PROFILE=your-notary-profile \
./scripts/package-release.sh
```

Release artifacts are written to the ignored `releases/` directory. To publish
the website with local release artifacts in place:

```sh
pnpm run deploy:worker
```

## License

TodoBar is available under the [MIT License](LICENSE).
