.PHONY: help install test clean format lint run-example build build-dist upload-testpypi upload-pypi clean-dist

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install dependencies
	pip install -r requirements.txt

install-dev: ## Install development dependencies
	pip install -r requirements-dev.txt

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
	./enr.py example.com http://localhost:3000 --dry-run

build: ## Build single script from modules
	python build_single_script.py

build-dist: ## Build distribution packages
	@echo "Building distribution packages..."
	python -m build
	@echo "✅ Distribution packages built successfully"
	@echo "📦 Files created:"
	@ls -la dist/

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
