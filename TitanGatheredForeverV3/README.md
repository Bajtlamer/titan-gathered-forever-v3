# Titan Gathered Forever v3

See the [project README](../README.md) for features, installation, history definitions, migration and releases.

The repository root contains the shared core and thirteen independently loadable optional addons. Development tools and catalogue inputs remain in this folder. Run from the repository root:

```sh
python3 TitanGatheredForeverV3/tools/generate_catalog.py
python3 TitanGatheredForeverV3/tools/check.py
python3 TitanGatheredForeverV3/tools/package.py
```

The GitHub workflow lives in the repository root's `.github/workflows/` directory. Saved-data migration instructions are in the project README.
