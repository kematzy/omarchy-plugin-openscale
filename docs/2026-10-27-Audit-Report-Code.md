# Code and Public-Release Readiness Audit

**Date:** 2026-10-27

**Project:** OpenScale for Omarchy

**Status:** 🟢 PASSED WITH FOLLOW-UP CHANGES

---

## Executive Summary

The plugin passes Omarchy's manifest/plugin validation, QML syntax validation, shell syntax
validation, and JSON parsing. A local smoke test of the model-cache helper passed, including cache
permissions and the sign-in error path. A scan of the available Git history found no matches for
common API-key or private-key patterns.

The audit initially found discrepancies in model refresh behavior and public-facing security/copy
descriptions. The owner confirmed that the screenshots are safe to publish and that `jq` is present
in Omarchy v4+. The model catalogue now reuses its cache for 24 hours; the README and technical
notes describe the policy. The README now discloses un-sandboxed execution and clarifies browser
links versus CLI API requests, and the low-balance text has been corrected. No release-blocking
code defect remains from this review.

## Follow-up Changes and Decisions

1. **Model catalogue reloads:** `Panel.qml` calls `ModelsTab.refresh()` whenever the Models tab
   becomes active. Previously, `ModelsTab.refresh()` always started a fetch; no local setting
   controlled it. `openRefreshGapSec` applies only to balance reads in `Service.qml`. `ModelsTab.qml`
   now waits for its initial cache read and fetches only if the catalogue is missing or at least
   24 hours old. The README and technical notes document this behavior.

2. **Screenshots:** The owner confirmed the displayed balance and usage values are safe to publish;
   no redaction was requested.

3. **Un-sandboxed execution:** The README's **Privacy & Security** section now explains that Omarchy
   plugins run un-sandboxed with the user's privileges and recommends reviewing the code before
   enabling it.

4. **`jq`:** The owner confirmed it is installed by default on the supported Omarchy v4+ platform,
   so the README does not list it as a separate requirement.

5. **User-facing text:** The low-balance helper and manifest description have been corrected.
   An unused QML import was also removed.

6. **Network disclosure:** The README now distinguishes account-data reads through `osc` from
   footer links opened in the browser.

## Checks Performed

- [x] `omarchy plugin validate .` — passed (exit 0).
- [x] `qmllint -I /tmp/qmlimports *.qml panel/*.qml` with the Omarchy import mapping — passed
      (exit 0), with no syntax errors. It reports known missing-property and unqualified-access
      warnings for the shell's QML singletons, host-injected properties, and nested components.
- [x] `bash -n models.sh` — passed.
- [x] `jq empty manifest.json` — passed.
- [x] Model-cache helper smoke test using a local fake `osc` command — cache read/refresh, mode
      `600`, and sign-in error rendering passed. No OpenScale network request was made.
- [x] Searched the available Git history for common API-key and private-key patterns; no matches found.
- [x] `git diff --check` — passed.
- [ ] Live end-to-end test with a signed-in OpenScale account — not run; it would access a real
      account and make network requests.
- [ ] `shellcheck` — unavailable in the environment.

## Statistics

| Metric                         |     Value |
| ------------------------------ | --------: |
| QML files reviewed             |        10 |
| JavaScript files reviewed      |         1 |
| Shell scripts reviewed         |         1 |
| Source lines reviewed          |     2,124 |
| Open release-blocking findings |         0 |
| Critical / High / Medium       | 0 / 0 / 0 |

## Recommendation

The repository is ready for public visibility from the checks performed here. Before tagging a
release, consider a manual install/enable smoke test in a disposable Omarchy environment with
a test OpenScale account. This audit does not change repository visibility, create a tag, or
publish a release.

## Next Audit

Re-audit after significant code changes or before a later major release.
