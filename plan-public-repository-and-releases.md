# Public Repository and Releases Plan

## Current status, 2026-11-08

Historical implementation/design record. Some original decisions and task restrictions were superseded. Use README.md, ref-wow-forever-runtime.md and plan-next-development.md for current behavior and remaining work. See [the roadmap](plan-next-development.md), [progress](ref-wow-forever-progress.md) and [unreleased changes](release-notes/ref-unreleased.md). Original step counts and no-install/no-commit statements below refer to their original execution, not the current installed/source-push status.

## Objective

Publish the Titan Gathered Forever v3 source under Bajtlamer, describe the complete crafter-assistance and lifetime-statistics goal accurately, and prepare individually selectable addon ZIPs plus the full collection for GitHub and website distribution.

## Scope

- Keep the development and Git root inside the installed `TitanGatheredForeverV3` core folder. Only TGF v3 runtime folders may be generated or modified. The user now explicitly authorizes creating a Git repository, superseding the earlier no-Git decision.
- Profession and Auction runtime folders remain siblings for WoW discovery. Their source data and generator live in the core repository and regenerate those independent addons on checkout.
- Move development JSON inputs into `catalogue/`, avoiding the macOS `data`/`Data` case collision. Keep manifest-loaded `Data/Metadata.lua` separate.
- Write README.md with goals, implemented behavior, action-counter/crafting/export gaps, statistical definitions, history start date, installation, independent packages and development commands. Preserve AGENTS.md verbatim.
- Extend packaging with a version-specific website upload folder containing exactly the current collection and fourteen individual ZIPs, SHA256SUMS and downloads.json. Keep package contents restricted to shipped runtime files.
- Add CI to regenerate and check a fresh checkout, plus a release workflow that uploads the same verified package set to GitHub. Keep local archives and generated distributions out of source control.
- Create local main branch and a focused source commit. Use the supplied Bajtlamer/titan-gathered-forever-v3 repository. Inspect its branches and tags before integrating and pushing the prepared source; preserve any existing remote work. Publish the current alpha with all downloads after verified access.

## Verification

Test release staging contents, dependency metadata, checksum integrity, clean reconstruction of sibling modules and runtime-only archive contents. Run the complete test suite, verify AGENTS.md hash and inspect the explicit Git file list. Never add other addons, local game settings, private archives or credentials. Report an external-access failure accurately without claiming publication.

## Current external constraint

GitHub CLI cannot connect to api.github.com in the current tool environment. Its authentication status output is therefore not sufficient to distinguish an invalid token from unavailable network access. Prepare all local work before retrying publication.


## Verification and publication status

Local preparation is complete. The full checker passes 169 tests and all shipped Lua compilation. A fresh reconstruction from the staged Git source, without existing profession folders, regenerates all fourteen addons and reproduces all seventeen website upload files byte-for-byte. Workflow YAML parses, and independent review found no Important or Critical issue.

GitHub publication remains blocked: `curl` confirms DNS resolution fails for `api.github.com`, and `gh repo create` cannot connect. The local source repository, intended origin and alpha tag are prepared, but no successful public repository creation, push, GitHub release or workflow execution has been observed. No credential change is required by the available evidence.


## User-supplied repository

The user supplied `https://github.com/Bajtlamer/titan-gathered-forever-v3.git` as the existing destination. The local origin and development/release documentation now use this URL. Both `gh repo view` and `git ls-remote` still fail because github.com/api.github.com cannot resolve in this environment. No remote history has been fetched and no push has occurred. Inspect the remote before pushing; integrate existing commits without force-pushing, and check existing release tags before publishing or changing the prepared local tag.


## Collection repository upload

The user initialized Git at the collection root and requested source upload. Root README and workflow now describe the fourteen-addon layout. The copied core repository metadata is archived under .work rather than becoming a nested Git repository. The remote Bajtlamer/titan-gathered-forever-v3 is public and empty; network access is available through the approved network execution path. Public source excludes private archives, build distributions and game SavedVariables. Upload only main; no release tag is pushed by this source-upload task.
