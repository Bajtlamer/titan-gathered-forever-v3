# Titan Gathered Forever 0.5.108

Small update to 0.5.107. This text is the changelog for the website and the release page.

## Added

- A warning at login when the old TitanGatheredForeverV3 folders are still installed next to the renamed ones. It names the folders and tells you which saved file to copy, so your saved data is not lost after the folder rename.

## Upgrading

The folders were renamed in 0.5.84 from TitanGatheredForeverV3 to TitanGatheredForever (and TitanGatheredForever_<Module>). Close the game, remove the old TitanGatheredForeverV3 folders from Interface/AddOns, extract the new folders, and copy your old SavedVariables file TitanGatheredForeverV3.lua to TitanGatheredForever.lua (same for each module) before starting the game. Enable the new modules in the AddOns list. A full client restart is required.
