# Repository Guidelines

## Project Structure & Module Organization

This repository contains Titan Gathered Forever v3, a World of Warcraft addon that tracks materials in bags and the bank.

- `TitanGatheredForeverV3/` holds shared tracking logic, English localization, UI XML, the `.toc` manifest, and `Artwork/TitanOre.tga`.
- `TitanGatheredForeverV3_<Profession>/` contains Cooking, Enchanting, Herbs, Mining, Skinning, and Tailoring modules. Each has Lua logic, English data/localization, XML, and a manifest.
- Manifests load XML; XML loads localization before module logic. Preserve this order and the declared dependencies on `Titan` and `TitanGatheredForeverV3`.

## Build, Test, and Development Commands

There is no build step or dependency installation. Copy the addon directories into the target WoW client's `Interface/AddOns/` directory and install Titan Panel separately. Enable the core addon and the modules being tested.

- `/reload`: reload the UI after Lua or XML edits.
- `/console scriptErrors 1`: enable Lua error reporting in game.
- `find TitanGatheredForeverV3* -name '*.lua' -exec luac -p {} \;`: check Lua syntax when a compatible Lua compiler is installed. This does not validate WoW API behavior.

The manifests declare interface version `90001`. Verify client compatibility before changing API calls or manifest versions.

## Coding Style & Naming Conventions

Follow nearby formatting: existing Lua mixes tabs and four-space indentation, with optional semicolons. Avoid unrelated reformatting. No formatter or linter configuration is provided.

Keep exported `TitanGatheredForeverV3*` names, uppercase constants such as `TG_*`, and existing module prefixes. Prefer local variables and namespace aliases for internal helpers. Keep item/category data in the corresponding English Lua file. Preserve XML callback names and manifest filenames when refactoring.

## Testing Guidelines

No automated test framework or coverage target is configured. Validate changes in game with the affected profession modules enabled. Check startup errors, material counts after looting, bank counts, tooltip contents, menu toggles, and persistence after `/reload`. For fixes, document the reproduction steps and observed result.

## Commit & Pull Request Guidelines

Git history is unavailable in this checkout, so no existing commit convention can be established. Use concise, imperative subjects, for example `Fix mining tooltip counts`. Keep changes focused.

Pull requests should describe the behavior changed, affected modules, client and Titan Panel versions, and validation performed. Link relevant issues and include screenshots for visible tooltip or menu changes.
