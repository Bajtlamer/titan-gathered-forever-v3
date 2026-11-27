# Publish Titan Gathered Forever v3 Releases

## Develop and install a candidate

Standing user instruction: install every completed, verified runtime update or new version into `/Applications/World of Warcraft/_forever_/Interface/AddOns` automatically. Follow `AGENTS.md` for verification, backups and reload/restart guidance. If live files already match, verify and report that state without creating a redundant backup. This is local-installation authorization; publication is a separate action.

1. Edit the source checkout, then run `python3 tools/check.py`. Use `python3 tools/package.py` when you also need distributable ZIPs. The installer builds its own candidate with the same runtime-file allowlist.
2. Close WoW before replacing addon folders. Choose the actual Forever client's existing `Interface/AddOns` directory, then preview from the repository root:

   ```sh
   python3 tools/install.py --addons-dir "/path/to/Forever/Interface/AddOns"
   ```

   Preview validates the candidate and lists all fourteen folders to add or replace. It makes no client changes. The destination is required; the tool does not guess which client to use.
3. Apply the reviewed candidate:

   ```sh
   python3 tools/install.py --addons-dir "/path/to/Forever/Interface/AddOns" --apply
   ```

   This installs the core and all thirteen optional addons. Enable only the modules you want in WoW. Existing TG3 folders are moved intact to a unique directory under `Interface/.tgf-v3-backups/`; the command prints that directory. Old backups remain available on subsequent installs. Unrelated addons, previous-generation folders and SavedVariables are preserved. Disable the previous generation yourself before enabling TG3.
4. Launch WoW with Titan Panel and the affected modules enabled. Enable Lua errors with `/console scriptErrors 1`; use `/reload` after subsequent configuration changes. Follow `book-wow-forever-validation.md`, checking startup, tooltips, bag/bank updates, maps, history and persistence. Automated checks do not establish live-client compatibility.

The installer stages the complete candidate before replacement and automatically restores original folders if an ordinary installation error occurs. Symlink destinations, symlink/file TG3 targets and source/destination overlap are rejected. An exclusive `Interface/.tgf-v3-install-lock` directory blocks simultaneous installer runs.

## Recover an earlier candidate

Close WoW. Locate the backup directory printed by the installation command. Move the fourteen current TG3 folders out of AddOns to a separate holding directory, then move only the backed-up TG3 folders into AddOns. A folder absent from that backup was absent before that installation, so leave it uninstalled to restore the exact previous selection. Do not move other addons or SavedVariables. Enable the previous selection and validate it in game.

If automatic recovery fails, the error reports the retained backup directory. This backup can be partial: some original folders may already have been restored in AddOns, and later folders may never have been touched. Restore each folder actually retained in the backup, moving its current AddOns counterpart into a separate holding directory first. Preserve other AddOns folders while inspecting their contents and your previous module selection. In this failure case, a missing backup folder does not establish that the addon was previously absent; do not follow the blanket fourteen-folder removal procedure above. Newly added candidate folders may need to be moved aside separately to recover your previous selection.

Hard termination or power loss can also interrupt automatic recovery. After confirming no installer is running, inspect the backup and any `.tgf-stage-*` directory under Interface, recover the desired folders using the partial-backup procedure, and remove an abandoned `.tgf-v3-install-lock` before retrying. Keep backups until live validation succeeds.

## Commit and push a source update

1. Update README.md, ref-wow-forever-progress.md, plans/plan-next-development.md and release-notes/ref-unreleased.md to describe current behavior and open issues. Preserve historical versioned release notes and mark superseded plans clearly.
2. Run python3 tools/check.py, python3 tools/audit_catalog.py --check, python3 tools/generate_pin_outlines.py --check and git diff --check. Inspect all staged paths for private files, SavedVariables, local archives, generated distributions and credentials.
3. Fetch the configured remote and check ancestry before pushing. Commit the reviewed source and documentation, then push the intended branch without force. A push to main runs verification/packaging CI; only a version tag invokes the publication job.
4. Verify the remote branch resolves to the new commit and report the commit and check results. Do not claim that a source push has published updated downloadable assets or changed the website.

Increment and synchronize the patch prerelease version for every completed runtime update, as required by the user. Source/test iterations and documentation-only evidence commits are not separate deployed updates. Version tags and GitHub release publication still require separate authorization.

## Prepare a version

1. Work from the repository root. Keep runtime changes limited to the TGF v3 addon folders.
2. Update `VERSION` in `tools/generate_catalog.py` and the version in `TitanGatheredForever/TitanGatheredForever.toc` together. Run `python3 tools/generate_catalog.py` to update profession manifests and generated data.
3. Add `release-notes/ref-<version>.md`. Describe implemented changes, meaningful validation and known limitations. Update README when scope or supported behavior changes.
4. Run `python3 tools/check.py` and the relevant in-game checks in `book-wow-forever-validation.md`.
5. Run `python3 tools/package.py`. It builds the collection, individual addon downloads and a clean `dist/releases/<version>/` upload directory. Rebuilding replaces that generated version directory.

## Check the download set

The upload directory contains exactly fifteen ZIPs and two metadata files:

- Full collection: `TitanGatheredForever-<version>.zip`.
- Core only: `TitanGatheredForever-<version>-core.zip`.
- Twelve profession ZIPs and one optional Auction Items ZIP.
- `downloads.json`: schema version, release version, client/interface, labels, filenames, dependencies, byte sizes and SHA-256 hashes.
- `SHA256SUMS`: checksums for ZIPs and the download index.

Every ZIP extracts addon folders directly under AddOns. Optional modules require the shared core and Titan Panel. The complete collection requires Titan Panel separately. Packages contain only manifest-listed runtime files and the core artwork.

On macOS, verify with `shasum -a 256 -c SHA256SUMS` from the upload directory. Linux CI uses `sha256sum --check SHA256SUMS`.

## Release the Discovery module

The Discovery module is released on its own and is not part of the collection or the fourteen ZIPs above. It has its own version line in its manifest (TitanGatheredForever_Discovery/TitanGatheredForever_Discovery.toc), listed in catalogue/standalone-modules.json.

1. Increment its patch version for every completed update and add `release-notes/ref-discovery-<version>.md`. Update curseforge/ref-titan-gathered-forever-discovery.md and the README section.
2. Run `python3 tools/check.py`, then `python3 tools/package.py --standalone`. The upload directory is `dist/standalone/TitanGatheredForever_Discovery-<version>/` with the ZIP, `downloads.json` and `SHA256SUMS`. Verify with `shasum -a 256 -c SHA256SUMS` from that directory.
3. Install locally with `python3 tools/install.py --addons-dir <path> --standalone-only` (preview first, then `--apply`). Only the Discovery folder is added or replaced, with a backup of the replaced one; no other folder and no saved file is touched.
4. The CI build creates the standalone package as a verification artifact (tgf-discovery-download); it does not publish it. Publishing the ZIP (GitHub or CurseForge) is a separate, explicit step, and the CurseForge project is separate from the core's projects.
5. The icon and artwork come from artwork/v1/TitanGatheredForever_Discovery/, drawn by `python3 tools/generate_discovery_art.py` and packaged by `python3 tools/generate_brand_icons.py`.

## Publish on GitHub

1. Commit the reviewed source on `main` and push it to `Bajtlamer/titan-gathered-forever-v3`.
2. Create a tag matching the manifest, such as `git tag v0.4.1-alpha`, then push that tag.
3. The release workflow reconstructs optional modules, checks the source, builds downloads and publishes all seventeen files. Versions containing a hyphen are published as prereleases.
4. Confirm the workflow passed and the release contains the full collection, core and all selected-module downloads. Never substitute GitHub's automatic source ZIP for an installable addon ZIP.

For an existing release, upload corrected assets explicitly after review; the workflow does not overwrite a published release silently.

## Publish on CurseForge

The ZIPs of `dist/releases/<version>/` go to the fourteen CurseForge projects (the core to Titan Gathered Forever, each module ZIP to its own project) with `tools/curseforge_upload.py`. It reads `CF_UPLOAD_TOKEN` from `../curseforge/.env` and never prints it; the project IDs are those of `../curseforge/ref-curseforge-project-ids.md`.

1. `python3 tools/curseforge_upload.py versions` lists the game versions; WoW Forever 1.60.1 is ID 17053 (type 88568).
2. `python3 tools/curseforge_upload.py plan --game-version 17053` shows the fourteen uploads without sending anything.
3. `python3 tools/curseforge_upload.py upload --apply --game-version 17053` uploads them as release files with the changelog of `release-notes/ref-<version>.md` (the core) or a short note (modules), and marks the modules as requiring the core. Use `--only <folder>` to send one project. A file that has been sent is not sent again by the tool: check the project's file list first.
4. The project descriptions are not part of the API; paste them from `curseforge/ref-*.md` on the author portal.

The release 0.5.167 (tag v0.5.167, merge commit a6edcae) was published on 2026-11-27: the GitHub release holds the seventeen assets of the workflow, byte-identical to the local package, and the fourteen CurseForge files were each uploaded once (file IDs 9851192 to 9851209, recorded in the upload ledger). The website still serves 0.5.164.

The release 0.5.164 (tag v0.5.164) was published on 2026-11-26: the GitHub release holds the seventeen assets of the workflow, the fourteen CurseForge files were each uploaded once (file IDs 9836580 to 9836595, recorded in the upload ledger), and the website 1.4.6 serves the same bytes.

The release 0.5.161 (tag v0.5.161) was published on 2026-11-23: the GitHub release holds the seventeen assets of the workflow, the fourteen CurseForge files were each uploaded once (file IDs 9782042 to 9782057, recorded in the upload ledger), and the website 1.4.5 serves the same bytes.

The release 0.5.156 (tag v0.5.156) was published on 2026-11-23: the GitHub release holds the seventeen assets of the workflow, the fourteen CurseForge files were each uploaded once (file IDs 9781023 to 9781037, recorded in the upload ledger), and the website 1.4.4 serves the same bytes.

The release 0.5.154 (tag v0.5.154) was published on 2026-11-23: the GitHub release holds the seventeen assets of the workflow, the fourteen CurseForge files were each uploaded once (file IDs 9779985 to 9780002, recorded in the upload ledger), and the website 1.4.3 serves the same bytes.

The release 0.5.151 (tag v0.5.151, commit 448fc17) was published on 2026-11-23: the GitHub release holds the seventeen assets of the workflow, the fourteen CurseForge files were uploaded the same day (they show after review; the core upload command may have been sent twice by mistake, so check the project file list), and the website 1.4.2 serves the same bytes.

The release 0.5.146 (tag v0.5.146, commit 6338d36) was published on 2026-11-23: the GitHub release holds nineteen assets (the seventeen of the workflow plus the Discovery 0.1.5 ZIP and its checksums), the fourteen CurseForge files are 9763653 to 9763667 (core 9763653), and the website serves the same bytes (website 1.4.1).

0.5.143 was uploaded on 2026-11-22 (file IDs 9742259 core, 9742265 Alchemy, 9742270 to 9742282 the other twelve modules), and the release 0.5.144 the same day (fourteen files, byte-identical to the GitHub release v0.5.144); CurseForge shows a file after its own review. Titan Gathered Discovery has no CurseForge project and is attached to the GitHub release as a separate ZIP.

## Prepare the website

Upload the contents of `dist/releases/<version>/` to the website's versioned downloads location. The directory is ready for manual upload; packaging does not connect to or change hosting. Use downloads.json to populate selectable downloads and dependencies. Serve the index and its matching ZIP set together, then verify links and checksums from the website.

## Source layout

Git is initialized at the collection root and tracks all fourteen runtime-only addon folders. Catalogue inputs, tools, tests, release notes, prefixed documents and AGENTS.md live at the root. CI runs root tools and verifies that addon directories contain only manifest files and required artwork. Local `.work/`, `dist/`, caches and temporary files remain ignored. Build clean candidates here, then install their runtime folders into WoW for in-game validation; do not develop directly in the live game installation.
