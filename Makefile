.PHONY: help install test clean format lint run-example build build-dist build-deb upload-testpypi upload-pypi clean-dist

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install dependencies
	pip install -r requirements.txt

install-dev: ## Install development dependencies
	pip install -r requirements-dev.txt

sync-version: ## Sync version from version.py to pyproject.toml
	@echo "🔄 Syncing version from version.py to pyproject.toml..."
	python update_version.py

test: ## Run tests
	python -m pytest tests/ -v

test-coverage: ## Run tests with coverage
	python -m pytest tests/ --cov=enr --cov-report=html

clean: ## Clean generated files
	rm -f default.conf
	rm -f *.proxy.conf
	rm -rf htmlcov/
	rm -rf .pytest_cache/
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete

clean-dist: ## Clean distribution files
	rm -rf dist/ build/ *.egg-info/

format: ## Format code with black
	black enr/ tests/

lint: ## Run ruff linting
	ruff check enr/ tests/

lint-fix: ## Run ruff linting with auto-fix
	ruff check --fix enr/ tests/

run-example: ## Run example with dry-run
	./enr.pyz example.com http://localhost:3000 --dry-run --force

build: ## Build single script from modules using zipapp
	@echo "🔨 Building single script from modules using zipapp..."
	@echo "📦 Creating temporary build directory..."
	@rm -rf temp_enr_build
	@mkdir -p temp_enr_build
	@echo "📝 Creating __main__.py entry point..."
	@python -c "import sys; sys.path.insert(0, '.'); from enr import __version__; print('''#!/usr/bin/env python3\n\"\"\"\nENR CLI utility for nginx config and Docker container management.\nVersion: ''' + __version__ + '''\n\"\"\"\n\nimport sys\nimport os\n\n# Add current directory to path for imports\nsys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))\n\n# Set version for the package\nimport enr\nenr.__version__ = \"''' + __version__ + '''\"\n\n# Import and run the CLI\nfrom enr.cli import main\n\nif __name__ == \"__main__\":\n    main()\n''')" > temp_enr_build/__main__.py
	@echo "📁 Copying enr package..."
	@cp -r enr temp_enr_build/
	@echo "🔧 Creating zipapp archive..."
	@python -m zipapp temp_enr_build -o enr.pyz -p "/usr/bin/env python3"
	@echo "🔒 Making executable..."
	@chmod +x enr.pyz
	@echo "🧹 Cleaning up..."
	@rm -rf temp_enr_build
	@echo ""
	@echo "📊 Build Information:"
	@echo "  📁 Output file: enr.pyz"
	@echo "  📏 Size: $$(du -h enr.pyz | cut -f1)"
	@echo "  📝 Lines: $$(wc -l < enr.pyz 2>/dev/null || echo 'N/A (binary)')"
	@echo "  🔐 SHA256: $$(sha256sum enr.pyz | cut -d' ' -f1)"
	@if [ -d .git ]; then \
		echo "  🏷️  Version: $$(python -c 'from enr import __version__; print(__version__)' 2>/dev/null || echo 'unknown')"; \
		echo "  🐙 Commit: $$(git rev-parse --short HEAD 2>/dev/null || echo 'not a git repo')"; \
	else \
		echo "  🏷️  Version: $$(python -c 'from enr import __version__; print(__version__)' 2>/dev/null || echo 'unknown')"; \
		echo "  🐙 Commit: not a git repo"; \
	fi

build-dist: ## Build distribution packages
	@echo "Building distribution packages..."
	flit build
	@echo "✅ Distribution packages built successfully"
	@echo "📦 Files created:"
	@ls -la dist/

build-deb: build ## Build DEB package using fpm
	@echo "🔍 Checking if fpm is installed..."
	@if ! command -v fpm >/dev/null 2>&1; then \
		echo "⚠️  fpm not found."; \
		if command -v apt-get >/dev/null 2>&1; then \
			echo "🔍 Detected debian-based distribution."; \
			echo "❓ Do you want to automatically install fpm? (y/N): "; \
			read -r response; \
			if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
				echo "📦 Installing dependencies for fpm..."; \
				sudo apt-get update && sudo apt-get install -y ruby ruby-dev rubygems build-essential; \
				echo "💎 Installing fpm gem..."; \
				sudo gem install --no-document fpm; \
				echo "✅ fpm installed successfully"; \
			else \
				echo "❌ Please install fpm manually: sudo apt install ruby ruby-dev rubygems build-essential && sudo gem install --no-document fpm"; \
				exit 1; \
			fi; \
		else \
			echo "❌ Please install fpm manually for your distribution"; \
			exit 1; \
		fi; \
	else \
		echo "✅ fpm is already installed"; \
	fi
	@echo "🔨 Building DEB package..."
	@VERSION=$$(python -c 'from enr import __version__; print(__version__)' 2>/dev/null || echo '0.1.1'); \
	fpm -s dir -t deb \
		--name enr \
		--version $$VERSION \
		--description "ENR CLI utility for nginx config and Docker container management" \
		--maintainer "Pavel Serikov <devpasha@proton.me>" \
		--depends python3 \
		enr.pyz=/usr/bin/enr
	@echo "✅ DEB package built successfully"
	@echo "📦 Files created:"
	@ls -la *.deb

check: format lint test ## Run all checks (format, lint, test)

upload-testpypi: build-dist ## Upload to Test PyPI
	@echo "Uploading to Test PyPI..."
	@echo "⚠️  Make sure you have registered on https://test.pypi.org/account/register/"
	@echo "⚠️  And created an API token in your account settings"
	twine upload --repository testpypi dist/*
	@echo "✅ Package uploaded to Test PyPI successfully"
	@echo "🔗 Test installation: pip install --index-url https://test.pypi.org/simple/ enr"

upload-pypi: build-dist ## Upload to PyPI
	@echo "Uploading to PyPI..."
	@echo "⚠️  Make sure you have registered on https://pypi.org/account/register/"
	@echo "⚠️  And created an API token in your account settings"
	twine upload dist/*
	@echo "✅ Package uploaded to PyPI successfully"
	@echo "🔗 Install: pip install enr"

pre-commit-install: ## Install pre-commit hooks
	@echo "Installing pre-commit hooks..."
	@if [ -f ".git/hooks/pre-commit" ]; then \
		chmod +x .git/hooks/pre-commit; \
		echo "✅ Native pre-commit hook installed"; \
	else \
		echo "❌ Pre-commit hook not found"; \
		exit 1; \
	fi
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install; \
		echo "✅ Pre-commit framework hooks installed"; \
	else \
		echo "⚠️  Pre-commit framework not installed. Run: pip install pre-commit"; \
	fi

pre-commit-run: ## Run pre-commit hooks manually
	@echo "Running pre-commit hooks..."
	@if [ -f ".git/hooks/pre-commit" ]; then \
		.git/hooks/pre-commit; \
	else \
		echo "❌ Pre-commit hook not found"; \
		exit 1; \
	fi

pre-commit-clean: ## Clean pre-commit cache
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit clean; \
		echo "✅ Pre-commit cache cleaned"; \
	else \
		echo "⚠️  Pre-commit framework not installed"; \
	fi
