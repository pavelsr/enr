# GitHub Actions Workflows

This project uses several GitHub Actions to automate CI/CD processes.

## Pipelines

### 1. CI (ci.yml)
**Triggers:** Push and Pull Request to `main` and `develop` branches

**Tasks:**
- **Lint**: Code checking with ruff, black and isort on Python 3.8-3.12
- **Test**: Running tests on Python 3.8-3.12
- **Build**: Package building (only for pushes to main)
- **Security**: Security checking with safety and bandit

### 2. Release (release.yml)
**Triggers:** Creating a new release

**Tasks:**
- Automatic package publishing to PyPI when creating a release
- Uses trusted publishing for secure publishing

### 3. Cross-Platform (cross-platform.yml)
**Triggers:** Push to main, PR to main, weekly on Sundays

**Tasks:**
- Testing on Ubuntu, Windows and macOS
- Compatibility checking with different Python versions
- CLI functionality testing on different OS

### 4. Dependencies (dependencies.yml)
**Triggers:** Weekly on Mondays, manual trigger

**Tasks:**
- Automatic pre-commit hooks updates
- Dependency vulnerability checking
- Creating Pull Request with updates

## Setup Requirements

### 1. Secrets (for release.yml)
For automatic PyPI publishing, you need to configure trusted publishing:

1. Go to [PyPI](https://pypi.org/manage/account/publishing/)
2. Add trusted publisher for your repository
3. Specify:
   - Owner: your GitHub username
   - Repository: pyenr
   - Workflow: release.yml
   - Environment: release

### 2. Branch Protection Rules
It's recommended to configure branch protection:

1. Go to Settings → Branches
2. Add rule for `main` branch:
   - Require status checks to pass
   - Require branches to be up to date
   - Status checks: CI / lint, CI / test

### 3. Environments
Create `release` environment in Settings → Environments for additional release protection.

## Usage

### Automatic Checks
All pipelines run automatically on:
- Push to main/develop
- Creating Pull Request
- Creating release
- On schedule

### Manual Trigger
Some pipelines can be triggered manually:
- Dependencies: Actions → Dependencies → Run workflow

### Creating a Release
1. Update version in `pyproject.toml`
2. Create git tag: `git tag v0.1.1`
3. Push tag: `git push origin v0.1.1`
4. Create release on GitHub with this tag
5. Package will be automatically published to PyPI

## Status Badges

Add badges to README.md to display status:

```markdown
[![CI](https://github.com/username/pyenr/workflows/CI/badge.svg)](https://github.com/username/pyenr/actions/workflows/ci.yml)
[![Release](https://github.com/username/pyenr/workflows/Release/badge.svg)](https://github.com/username/pyenr/actions/workflows/release.yml)
[![Python](https://img.shields.io/pypi/pyversions/enr)](https://pypi.org/project/enr/)
[![PyPI](https://img.shields.io/pypi/v/enr)](https://pypi.org/project/enr/)
```
