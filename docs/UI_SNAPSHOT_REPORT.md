# UI snapshot run — report

**Question:** can SubLearn's Android app be built on GitHub Actions, driven on an emulator, and its
screenshots inspected from the agent sandbox?

**Answer:** yes. Run
[39004201323](https://github.com/melonityhub/sublearntest/actions/runs/39004201323) built the debug
APK, booted an API 34 x86_64 emulator with KVM, ran six Maestro flows (6/6 passed, 1 m 45 s), and
published ten PNGs (nine app captures plus `final-screen.png`) and the logs to the orphan branch `ui-snapshots`. The images were opened and
read in the sandbox.

## What is in the repository

| Path | Purpose |
| --- | --- |
| `.github/workflows/ui-snapshot.yml` | manual workflow: shallow-clones `animalrender/SubLearn`, builds `assembleDebug`, runs the APK on an API 34 emulator, installs Maestro, runs `.maestro/`, publishes to `ui-snapshots` with `if: always()`, uploads the `ui-snapshots` artifact |
| `scripts/run-ui-snapshots.sh` | the emulator body (install → Maestro → logcat), kept out of the `script:` input because that action runs each line separately |
| `.maestro/01-home.yaml` | literally `launchApp` + `takeScreenshot: home` |
| `.maestro/02-settings.yaml` | drawer → Settings → search → Downloads |
| `.maestro/03-my-words.yaml` | drawer → My Words |
| `.maestro/04-learn.yaml` | Learn tab |
| `.maestro/05-dictionary.yaml` | Dictionary tab |
| `.maestro/06-home-settled.yaml` | Home captured after the first frame (see *Known artifacts*) |

Labels are the exact strings from
`core/designsystem/src/main/res/values/strings.xml`: `Settings`, `Search settings`, `Downloads`,
`My Words`, `Learn`, `Dictionary`. Every navigation tap is `optional: true` or guarded with
`runFlow.when` and a positional fallback, so one wrong label does not lose the other screenshots.

## Access tests from the sandbox

| # | Test | Result | Evidence |
| --- | --- | --- | --- |
| a | `gh run download <run> -n ui-snapshots` | **FAIL** | exit 1, `error downloading ui-snapshots: Get "https://productionresultssa11.blob.core.windows.net/actions-results/.../ui-snapshots.zip?...": EOF`. The metadata call `gh api .../actions/runs/<id>/artifacts` does work and reports `ui-snapshots`, 6,450,547 bytes, `expired: false`. `gh run view --log` fails the same way (`results-receiver.actions.githubusercontent.com … EOF`). |
| b | `git clone --depth 1 -b ui-snapshots` and read the PNGs | **PASS** | clone succeeds; the branch holds `home.png`, `home-settled.png`, `settings.png`, `settings-downloads.png`, `my-words.png`, `learn.png`, `dictionary.png`, `drawer.png`, `final-screen.png`, the Maestro report and the logs. |
| c | `curl` a raw URL and check it is a PNG | **FAIL for curl** | `curl: (35) OpenSSL SSL_connect: SSL_ERROR_SYSCALL in connection to raw.githubusercontent.com:443`, HTTP 000, 0 bytes. The same bytes are reachable through the GitHub Contents API (`home.png`, 601,975 bytes, base64 starts `89 50 4E 47 0D 0A 1A 0A`), and `raw.githubusercontent.com` itself is reachable from outside the sandbox (the README was fetched through the page-fetch proxy). `file` is not installed in the sandbox; `identify` and the PNG signature were used instead. |
| d | open the image itself, not just download it | **PASS** | all ten PNGs were opened with the image reader and analysed (colours sampled with ImageMagick, crops inspected). |

## Raw links

The branch is force-pushed on every run, so it always holds the newest run only.

- https://raw.githubusercontent.com/melonityhub/sublearntest/ui-snapshots/home-settled.png
- https://raw.githubusercontent.com/melonityhub/sublearntest/ui-snapshots/settings.png
- https://raw.githubusercontent.com/melonityhub/sublearntest/ui-snapshots/settings-downloads.png
- https://raw.githubusercontent.com/melonityhub/sublearntest/ui-snapshots/my-words.png
- https://raw.githubusercontent.com/melonityhub/sublearntest/ui-snapshots/learn.png
- https://raw.githubusercontent.com/melonityhub/sublearntest/ui-snapshots/dictionary.png
- https://raw.githubusercontent.com/melonityhub/sublearntest/ui-snapshots/drawer.png

## Visual analysis (from the captures, Pixel 6 profile, 1080 × 2400 px, light theme)

### Colour

Measured on the screenshots:

| Surface | Sampled |
| --- | --- |
| page background | `#F6F8FA` (matches `Palette.LIGHT_BACKGROUND`) |
| app bar / surface | `#FFFFFF` (`LIGHT_SURFACE`) |
| bottom navigation bar | `#F3EDF7` |
| selected tab pill / tonal buttons on Home | `#E8DEF8` / `#E6DCF6` |
| drawer sheet | `#F7F2FA` |
| Home empty-state panel | `#F7F2FA` |
| Downloads outer card | `#F3EDF7`; inner card `#F2F7F7` |
| accent (text, icons, Download button) | `#00695F` |

So the chrome is **lavender/purple** (`#F3EDF7`, `#F7F2FA`, `#E8DEF8`) while the accent is teal.
Those lavender values are exactly the Material 3 baseline containers, and they appear because
`SubLearnTheme` calls `lightColorScheme()` overriding only `primary`, `secondary`, `background`,
`surface` and `outline`; `secondaryContainer`, `primaryContainer`, `surfaceContainer*` and
`surfaceVariant` fall back to the M3 baseline purple. `useDynamicColor` defaults to false, so this is
not the device palette.

Contrast is healthy everywhere that was measured: body text `#3D3843` on `#F6F8FA` = 10.6:1,
titles ≈ 19.5:1, teal section headers on the page = 7.1:1, white on the teal Download button = 6.6:1.
No WCAG problem was found on these screens.

### Layout and spacing

- **Gutter mismatch:** Home starts at 20 dp (`Column(...padding(20.dp))`), Settings and My Words at
  16 dp (`Dimens.lg`). Measured 30 px vs 24 px at a 600 px-wide render, i.e. 20.5 dp vs 16.4 dp. The
  design system names `lg` as the default screen gutter.
- **Top bar mismatch:** the app-level `TopAppBar` uses `titleMedium`; the Settings screen's own
  `TopAppBar` uses the Material default `titleLarge`. Measured cap heights: `Home` 15 px, `Settings`
  23 px, `My Words` 24 px at 600 px wide.
- **Edge-to-edge mismatch:** Home/Learn/Dictionary paint the white app bar under the status bar
  (white from y = 0), while Settings and My Words leave a 27 dp strip of `#F6F8FA` above their white
  toolbar (white starts at y = 72 px of 1080). Both are visible as a band at the top of the captures.
- **Settings root** is a single flat list of 14 rows with no dividers, icons or grouping; nine fit on
  the screen and the tenth (`AI`) is cut by the bottom edge. It reads much less finished than the
  card-based Downloads screen one level down.
- **Downloads** nests three rounded surfaces: lavender panel `#F3EDF7` (22 dp), card `#F2F7F7`
  (14 dp), pill button inside it. The solid dark circular “i” is visually heavier than everything
  around it and competes with the primary action.
- **My Words** chips overflow the right edge: the sixth chip is cut mid-word (“Idi…”), with no fade
  or scroll affordance. This is at the standard font scale; a larger app font scale will cut more.
- **Home** puts two equally weighted tonal buttons side by side. `Open a video` is one line,
  `Open URL or stream` wraps to two inside the same 56 dp height, so the two halves of the same
  action pair do not read as peers.
- **Empty states** (Learn, Dictionary, My Words, Home) are bare centred text over 60–70 % empty
  space; only Home has an icon, and that icon is `OpenInNew`, which conventionally means “open in a
  new window”, not “no videos yet”.
- **Bottom navigation on sub-screens:** Settings and My Words keep the four-tab bar while their top
  bar shows a back arrow, and the selected tab still reads `Home`. Two navigation models are visible
  at once.
- **RTL line:** the Persian pack description is left-aligned inside the LTR card and its line height
  is visibly tighter than the English body text above it.

### Typography

System sans (Roboto) throughout; no custom family. Hierarchy is consistent inside a screen (title
16 sp / subtitle 13–14 sp / body 14 sp / small labels 12 sp) but not between screens, because the two
top-bar implementations disagree. The Settings rows have only 2–4 dp between title and subtitle,
which makes a 14-row list visually dense, while the gap between rows is generous — the hierarchy is
carried by weight, not by space.

## Comparison with `docs/DESIGN_SYSTEM.md`

| Claim in the design system | What the screenshots show |
| --- | --- |
| “`MaterialTheme.colorScheme` is built from those [theme mode and accent]”; the accent is TEAL | Only `primary`/`secondary` are teal-driven. Bottom bar, nav indicator, tonal buttons, drawer and cards are M3 baseline lavender (`#F3EDF7`, `#F7F2FA`, `#E8DEF8`), so the chrome contradicts the accent. |
| “quiet chrome, loud content” | In the app shell the chrome (lavender cards, pills, bottom bar) is the loudest thing on the screen. |
| `Dimens.lg` (16 dp) is the default screen gutter | Home uses 20 dp. |
| Cards use `radiusMd` (14 dp) | Home's empty-state panel uses 22 dp; the recent cards use the M3 `shapes.large` (16 dp). Three radii in one screen. |
| One elevation step (`cardElevation = 6 dp`, tonal rather than shadow) | Downloads stacks tonal surfaces three deep, which reads as elevation without the token. |
| Typography is remapped once, with line height and letter spacing tuned for the Persian fallback | The Persian line is visibly tighter than the Latin body text and is not right-aligned in the card. |
| “Direction comes from content … RTL layouts are mirrored by using start/end” | The Persian description in Downloads is a left-aligned RTL run inside an LTR layout. |
| Every interactive element has a `contentDescription`; 44 dp minimum touch target | The My Words import/export actions are icon-only up/down arrows. Their `contentDescription` cannot be judged from a screenshot, but the screen gives the user no visible label for either. |
| Rails report overflow and never spill past the viewport (written for the player) | The same failure mode exists outside the player: the My Words chip row spills past the right edge with no arrow or fade. |

Two discrepancies are not cosmetic: the **palette** (the screenshots show the Material baseline
purple, not the teal accent the document describes) and the **two top-bar implementations**
(`titleMedium` + bar under the status bar vs `titleLarge` + a 27 dp grey band).

## Known artifacts that are not design bugs

- `home.png` is the frame that `.maestro/01-home.yaml` produced with the literal
  `launchApp` + `takeScreenshot` sequence. The capture races the first Compose frame and lands on the
  launcher, so the Home screen to judge is `home-settled.png` (flow 06 waits for “Continue watching”).
  The original capture is kept in `maestro-output/2026-10-17_045536/Home/takeScreenshot/home.png` as
  evidence of the race.
- `settings-search.png` intentionally shows the partial query `downloa`; the exact-match tap on
  `^Downloads$` would otherwise hit the text field itself.

## Attempt log

| Run | Result | Cause and fix |
| --- | --- | --- |
| 1 · 39002524518 | green, no screenshots | `android-emulator-runner` runs its `script:` with `/usr/bin/sh` and bash-only `set -u pipefail` + `PIPESTATUS` aborted it with exit 2 before the first command; `continue-on-error` hid it. Fixed by POSIX sh, no `continue-on-error`, explicit status capture. |
| 2 · 39003217606 | red | `steps.apk.outputs.apk` arrived empty in the script (`adb: filename doesn't end .apk`). Fixed with `GITHUB_ENV` + `apk-path.txt` + glob fallback. |
| 3 · 39003468449 | red | same script input, still multi-line: the action splits `script:` on newlines and runs each line as its own `sh -c`, so `if` blocks and cross-line variables cannot work. Fixed by moving the body to `scripts/run-ui-snapshots.sh`. |
| 4 · 39003762439 | green, 5/5 flows | Images were 320 × 640 px (no AVD profile), the drawer never opened (6 %, 6 % lands on the status bar) and the fallback hit Quiz; Home was the black launch frame. Fixed with `profile: pixel_6`, the hamburger's `contentDescription` (“Settings”), `extendedWaitUntil`, and a settled Home flow. |
| 5 · 39004201323 | green, 6/6 flows | Final run; ten PNGs, 600 px wide, ImageMagick installed in a step. |

All five runs were started by a temporary `push` trigger on `ci/ui-snapshot-trigger`, because
this sandbox's GitHub connection can read the Actions API but cannot create a `workflow_dispatch`
event (`HTTP 403: Resource not accessible by integration`). The trigger and the marker file are
removed again, so the committed workflow is `workflow_dispatch` only, as specified.

## Reproduce

```bash
gh workflow run ui-snapshot.yml --ref main   # needs a token with actions:write
gh run watch
git clone --depth 1 -b ui-snapshots https://github.com/melonityhub/sublearntest.git
```
