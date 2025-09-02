"""Tests for single script functionality."""

import subprocess
import tempfile
from pathlib import Path


def test_single_script_help():
    """Test that single script shows help."""
    result = subprocess.run(
        ["./enr.pyz", "--help"],
        capture_output=True,
        text=True,
        cwd=Path(__file__).parent.parent,
    )

    assert result.returncode == 0
    assert "Generate nginx config and run Docker container" in result.stdout
    assert "server_name" in result.stdout
    assert "proxy_pass" in result.stdout


def test_single_script_dry_run():
    """Test single script dry run functionality."""
    with tempfile.TemporaryDirectory() as temp_dir:
        result = subprocess.run(
            [
                "./enr.pyz",
                "test.com",
                "http://localhost:3000",
                "--dry-run",
                "--force",
                "--config-dir",
                temp_dir,
            ],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent,
        )

        assert result.returncode == 0
        assert "Generated nginx config:" in result.stdout
        assert "test.com.proxy.conf" in result.stdout
        assert "Dry run mode - Docker container not started" in result.stdout
        assert "Generated nginx configuration:" in result.stdout
        assert "Docker command that would be executed:" in result.stdout

        # Check that config file was created
        config_path = Path(temp_dir) / "test.com.proxy.conf"
        assert config_path.exists()

        # Check config content
        content = config_path.read_text()
        assert "server_name test.com;" in content
        assert "proxy_pass http://localhost:3000;" in content


def test_single_script_dry_run_with_https():
    """Test single script dry run with HTTPS."""
    with tempfile.TemporaryDirectory() as temp_dir:
        result = subprocess.run(
            [
                "./enr.pyz",
                "api.test.com",
                "https://api.example.com",
                "--dry-run",
                "--force",
                "--config-dir",
                temp_dir,
            ],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent,
        )

        assert result.returncode == 0
        assert "Generated nginx config:" in result.stdout
        assert "api.test.com.proxy.conf" in result.stdout
        assert "LETSENCRYPT_HOST=api.test.com" in result.stdout
        assert "LETSENCRYPT_EMAIL=443@api.test.com" in result.stdout
        assert (
            "Let's Encrypt SSL variables will be added for HTTPS proxy_pass"
            in result.stdout
        )

        # Check that config file was created
        config_path = Path(temp_dir) / "api.test.com.proxy.conf"
        assert config_path.exists()

        # Check config content
        content = config_path.read_text()
        assert "server_name api.test.com;" in content
        assert "proxy_pass https://api.example.com;" in content


def test_single_script_auto_add_protocol():
    """Test single script auto-adds http:// protocol."""
    with tempfile.TemporaryDirectory() as temp_dir:
        result = subprocess.run(
            [
                "./enr.pyz",
                "test.com",
                "localhost:3000",
                "--dry-run",
                "--force",
                "--config-dir",
                temp_dir,
            ],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent,
        )

        assert result.returncode == 0
        assert (
            "Auto-added http:// to proxy_pass: http://localhost:3000" in result.stdout
        )

        # Check that config file was created
        config_path = Path(temp_dir) / "test.com.proxy.conf"
        assert config_path.exists()

        # Check config content
        content = config_path.read_text()
        assert "proxy_pass http://localhost:3000;" in content


def test_single_script_error_handling():
    """Test single script error handling."""
    result = subprocess.run(
        [
            "./enr.pyz",
            "test.com",
            "http://localhost:3000",
            "--config-dir",
            "/nonexistent",
        ],
        capture_output=True,
        text=True,
        cwd=Path(__file__).parent.parent,
    )

    assert result.returncode == 1
    assert "Error: Config directory" in result.stderr
