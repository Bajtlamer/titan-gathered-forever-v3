# Publish Titan Gathered Forever v3 Releases

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
