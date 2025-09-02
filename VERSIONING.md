# Version Management Guide

This project uses a centralized version management system with flit for building. The version is stored in **ONE PLACE ONLY** and automatically propagated to all other files using flit's built-in dynamic version support.

## How It Works

1. **Single source of truth**: Version is stored **ONLY** in `version.py` in the project root
2. **Automatic propagation**: All other files automatically get the version from this file
3. **Flit dynamic versioning**: Uses flit's built-in `dynamic = ["version"]` feature
4. **No git dependency**: Version management works independently of git tags
5. **No manual sync needed**: Version is automatically read from module during build

## Files That Get Version Automatically

- `enr/__init__.py` - imports version from `version.py`
- `pyproject.toml` - gets version automatically via flit's dynamic versioning
- Distribution packages (wheel, tar.gz) - get the correct version in their names
- Single script (`enr.sh`) - gets version from `version.py`

## To Change Version

**ONLY ONE STEP REQUIRED:**

1. **Update version in `version.py`**:
   ```python
   __version__ = "1.0.0"
   ```

**That's it!** All other files automatically get the new version when you run:
- `make build` - builds single script with current version
- `make build-dist` - builds distribution packages with current version

## File Structure

```
pyenr/
├── version.py          # ← MAIN VERSION FILE (change here ONLY)
├── pyproject.toml      # ← gets version automatically via flit dynamic
├── setup.py            # ← imports version from version.py
├── enr/
│   └── __init__.py     # ← imports version from version.py
└── dist/               # ← packages get version automatically
```

## Example Workflow

```bash
# 1. Change version in version.py (ONLY THIS FILE)
echo '__version__ = "1.0.0"' > version.py

# 2. Build distribution (version will be 1.0.0 automatically)
make build-dist

# 3. Check that version is correct
python -c "import enr; print(enr.__version__)"
# Output: 1.0.0
```

## Benefits

- ✅ **True single source of truth**: Version managed in ONE file only
- ✅ **Automatic updates**: All files get the correct version automatically
- ✅ **Modern tooling**: Uses flit's built-in dynamic versioning
- ✅ **No git dependency**: Works without git tags or git history
- ✅ **Simple and reliable**: Just change one file and rebuild
- ✅ **No manual errors**: Impossible to forget updating version in some files
- ✅ **No manual sync**: Flit automatically reads version from module
- ✅ **Standard approach**: Follows flit's recommended practices

## Configuration Files

The version management is configured in:
- `version.py` - **MAIN VERSION FILE** (change version here ONLY)
- `pyproject.toml` - uses `dynamic = ["version"]` for automatic version detection
- `enr/__init__.py` - imports version from `version.py`
- `setup.py` - imports version from `version.py`

## Building with Flit

This project uses flit for building Python packages with dynamic versioning:

```bash
# Build distribution packages (automatically gets version from module)
make build-dist

# Build single script (gets version from version.py)
make build

# Or use flit directly
flit build

# Install in development mode
flit install --symlink
```

## How Flit Dynamic Versioning Works

1. **`pyproject.toml`** has `dynamic = ["version"]`
2. **`enr/__init__.py`** contains the `__version__` variable
3. **Flit** automatically reads `__version__` from the module during build
4. **No manual synchronization** needed - everything happens automatically

## Troubleshooting

**Q: Version didn't update after changing version.py?**
A: Make sure to run `make build` or `make build-dist` after changing the version. Flit will automatically read the new version.

**Q: Import error when importing version?**
A: The system has fallbacks - if `version.py` can't be imported, it will use a default version.

**Q: How to check current version?**
A: Run `python -c "import enr; print(enr.__version__)"`

**Q: Flit build failed?**
A: Make sure all files are committed to git, as flit requires a clean git state.

**Q: How does dynamic versioning work?**
A: Flit automatically reads the `__version__` variable from your module during build. No manual sync needed!
