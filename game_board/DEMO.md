# Portfolio demo

A demo build of the game board app runs entirely in the browser. It never contacts the server, and it holds no real data: every player in it is made up.

## What visitors can do

- **Play the single-player games**: Blackjack, Crazy Eights and Checkers. These run entirely on the device in the full app too, so they're exactly the same.
- **Look around the profile**: stats, bankroll and changing the username.
- **Use the social panel**: search for players, send, accept, reject and cancel friend requests, remove friends, block, unblock and report.

**Online play** and the **chat test** need the live Node.js and Socket.IO server, so in the demo the Play Online button explains that instead of opening the lobby, and the chat test button is hidden.

## How it works

`AuthService`, `SocialService` and `ImageUploadService` send every request through one `http.Client`, `apiClient` in `lib/services/api_client.dart`. In a demo build (`--dart-define=DEMO=true`) that client is `DemoBackend`, an in-memory fake of the REST API, instead of the browser's HTTP client.

Because the swap happens below the services, every screen, model and error message runs exactly as it does in production. Only the transport changes. This is the same approach as the Rota Manager demo.

| File | Purpose |
| --- | --- |
| `lib/demo/demo_mode.dart` | The `isDemo` flag, read from `--dart-define=DEMO=true` |
| `lib/demo/demo_backend.dart` | Fake API: the same routes, status codes, JSON shapes and rules as `routes/auth.js`, `routes/game.js` and `routes/social.js` on the server |
| `lib/demo/demo_seed.dart` | The demo account and ten made-up players, with friends and pending requests already in place |
| `lib/demo/demo_widgets.dart` | The "Demo" banner, the one-click login panel and the "online play isn't in the demo" dialog |
| `lib/services/api_client.dart` | The shared client the services use |
| `test/demo_backend_test.dart` | Checks the fake API against the app's own `User` model and the server's rules |
| `build_demo.ps1` | Tests and builds the demo, then zips it for upload |

The only changes outside `lib/demo/` are:

- The three services call `apiClient` instead of the top-level `http` functions.
- `main.dart` adds the banner.
- `login_screen.dart` shows the login panel above the login form.
- `home_screen.dart` shows the dialog for Play Online and hides the chat test.
- `profile_screen.dart` says photo uploads are turned off.

A normal build (without `DEMO=true`) behaves exactly as before.

Two small fixes came with it, and they help normal builds too:

- `web/index.html` now uses Flutter's `$FLUTTER_BASE_HREF` placeholder instead of a fixed `/`, so `--base-href` works. Builds without `--base-href` still get `/`.
- `pubspec.yaml` no longer lists `assets/images/` and `assets/sounds/`. Those folders aren't in the repo and nothing uses them, and a fresh clone wouldn't build with them listed.

### The demo account

| Email | Password |
| --- | --- |
| demo@example.com | demo1234 |

Visitors don't need these, because the login page has a one-click **Play as DemoPlayer** button.

The account starts with a 1,250 bankroll and some games already played. It's friends with LuckyLuna, KingMeKev and CardSharpSam, has a friend request from RiverRaj, and is waiting on a request to QueenOfClubs. The other made-up players can be found by searching.

### What's turned off

- **Creating an account** shows a "turned off in the demo" message, because new accounts need their email verified.
- **Photo uploads**, **password changes** and **deleting the account** show a "turned off in the demo" message.
- **Password resets** go as far as asking for a code, and then say resets are turned off.
- **Reports** and **friend requests** report success but go nowhere.

Changes last until the page is refreshed. Each page load also issues fresh tokens, so after a refresh the visitor starts again at the login page.

## Building

From PowerShell in `game_board`:

```powershell
.\build_demo.ps1
```

This runs the demo tests, builds to `build\web-demo` with a base href of `/game-demo/`, and creates `build\game-demo.zip`.

To build for the root of its own subdomain (for example `games-demo.microaardvark.co.uk`), run this instead:

```powershell
.\build_demo.ps1 -BaseHref "/"
```

To run the demo locally while working on it:

```powershell
flutter run -d chrome --dart-define=DEMO=true
```

## Deploying to cPanel

1. In File Manager, open the document root of `portfolio.microaardvark.co.uk` and create a folder called `game-demo`.
2. Upload `build\game-demo.zip` into that folder, then right-click it and choose **Extract**. Delete the zip afterwards.
3. Open `https://portfolio.microaardvark.co.uk/game-demo/` to check it loads.
4. Link to it from the portfolio page.

The app doesn't use named routes, so no `.htaccess` rewrite rules are needed.

When you redeploy, delete the old files first. Flutter's service worker can cache an old build, so check in a private window or do a hard refresh.

## Keeping the demo up to date

When you add or change a REST route in the server, add the matching route to `DemoBackend`. Otherwise that screen will show the "Not found" error in the demo. The tests catch JSON shape mismatches for the routes they cover.
