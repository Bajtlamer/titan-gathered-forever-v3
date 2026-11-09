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

1. Update README.md, ref-wow-forever-progress.md, plan-next-development.md and release-notes/ref-unreleased.md to describe current behavior and open issues. Preserve historical versioned release notes and mark superseded plans clearly.
2. Run python3 tools/check.py, python3 tools/audit_catalog.py --check, python3 tools/generate_pin_outlines.py --check and git diff --check. Inspect all staged paths for private files, SavedVariables, local archives, generated distributions and credentials.
3. Fetch the configured remote and check ancestry before pushing. Commit the reviewed source and documentation, then push the intended branch without force. A push to main runs verification/packaging CI; only a version tag invokes the publication job.
4. Verify the remote branch resolves to the new commit and report the commit and check results. Do not claim that a source push has published updated downloadable assets or changed the website.

Increment and synchronize the patch prerelease version for every completed runtime update, as required by the user. Source/test iterations and documentation-only evidence commits are not separate deployed updates. Version tags and GitHub release publication still require separate authorization.

## Prepare a version

1. Work from the repository root. Keep runtime changes limited to the TGF v3 addon folders.
2. Update `VERSION` in `tools/generate_catalog.py` and the version in `TitanGatheredForeverV3/TitanGatheredForeverV3.toc` together. Run `python3 tools/generate_catalog.py` to update profession manifests and generated data.
3. Add `release-notes/ref-<version>.md`. Describe implemented changes, meaningful validation and known limitations. Update README when scope or supported behavior changes.
4. Run `python3 tools/check.py` and the relevant in-game checks in `book-wow-forever-validation.md`.
5. Run `python3 tools/package.py`. It builds the collection, individual addon downloads and a clean `dist/releases/<version>/` upload directory. Rebuilding replaces that generated version directory.

## Check the download set

The upload directory contains exactly fifteen ZIPs and two metadata files:

- Full collection: `TitanGatheredForeverV3-<version>.zip`.
- Core only: `TitanGatheredForeverV3-<version>-core.zip`.
- Twelve profession ZIPs and one optional Auction Items ZIP.
- `downloads.json`: schema version, release version, client/interface, labels, filenames, dependencies, byte sizes and SHA-256 hashes.
- `SHA256SUMS`: checksums for ZIPs and the download index.

Every ZIP extracts addon folders directly under AddOns. Optional modules require the shared core and Titan Panel. The complete collection requires Titan Panel separately. Packages contain only manifest-listed runtime files and the core artwork.

On macOS, verify with `shasum -a 256 -c SHA256SUMS` from the upload directory. Linux CI uses `sha256sum --check SHA256SUMS`.

## Publish on GitHub

1. Commit the reviewed source on `main` and push it to `Bajtlamer/titan-gathered-forever-v3`.
2. Create a tag matching the manifest, such as `git tag v0.4.1-alpha`, then push that tag.
3. The release workflow reconstructs optional modules, checks the source, builds downloads and publishes all seventeen files. Versions containing a hyphen are published as prereleases.
4. Confirm the workflow passed and the release contains the full collection, core and all selected-module downloads. Never substitute GitHub's automatic source ZIP for an installable addon ZIP.

For an existing release, upload corrected assets explicitly after review; the workflow does not overwrite a published release silently.

## Prepare the website

Upload the contents of `dist/releases/<version>/` to the website's versioned downloads location. The directory is ready for manual upload; packaging does not connect to or change hosting. Use downloads.json to populate selectable downloads and dependencies. Serve the index and its matching ZIP set together, then verify links and checksums from the website.

## Source layout

Git is initialized at the collection root and tracks all fourteen runtime-only addon folders. Catalogue inputs, tools, tests, release notes, prefixed documents and AGENTS.md live at the root. CI runs root tools and verifies that addon directories contain only manifest files and required artwork. Local `.work/`, `dist/`, caches and temporary files remain ignored. Build clean candidates here, then install their runtime folders into WoW for in-game validation; do not develop directly in the live game installation.
