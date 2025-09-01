"""Tests for CLI functionality."""

import tempfile
from pathlib import Path
from unittest.mock import patch

# Note: pytest is not directly used in this file
from enr.cli import main


def test_cli_auto_adds_http_protocol():
    """Test auto-adding http:// to proxy_pass if not specified."""
    with tempfile.TemporaryDirectory() as temp_dir:
        with patch(
            "sys.argv",
            [
                "enr.py",
                "example.com",
                "example.tilda.ws",
                "--dry-run",
                "--force",
                "--config-dir",
                temp_dir,
            ],
        ):
            with patch("sys.stdout") as mock_stdout:
                with patch("sys.stderr"):
                    main()

                    # Check that info message was printed
                    output = mock_stdout.write.call_args_list
                    output_text = "".join([call[0][0] for call in output])
                    assert (
                        "Auto-added http:// to proxy_pass: http://example.tilda.ws"
                        in output_text
                    )

                    # Check that config file was generated
                    config_path = Path(temp_dir) / "example.com.proxy.conf"
                    assert config_path.exists()

                    # Check that config contains the correct proxy_pass
                    content = config_path.read_text()
                    assert "proxy_pass http://example.tilda.ws;" in content


def test_cli_preserves_existing_protocol():
    """Test preserving existing http:// or https:// protocol."""
    with tempfile.TemporaryDirectory() as temp_dir:
        with patch(
            "sys.argv",
            [
                "enr.py",
                "example.com",
                "https://api.example.com",
                "--dry-run",
                "--force",
                "--config-dir",
                temp_dir,
            ],
        ):
            with patch("sys.stdout") as mock_stdout:
                with patch("sys.stderr"):
                    main()

                    # Check that no auto-add message was printed
                    output = mock_stdout.write.call_args_list
                    output_text = "".join([call[0][0] for call in output])
                    assert "Auto-added http:// to proxy_pass" not in output_text

                    # Check that config file was generated
                    config_path = Path(temp_dir) / "example.com.proxy.conf"
                    assert config_path.exists()

                    # Check that config contains the correct proxy_pass
                    content = config_path.read_text()
                    assert "proxy_pass https://api.example.com;" in content


def test_cli_handles_localhost_without_protocol():
    """Test handling localhost:port without protocol."""
    with tempfile.TemporaryDirectory() as temp_dir:
        with patch(
            "sys.argv",
            [
                "enr.py",
                "example.com",
                "localhost:3000",
                "--dry-run",
                "--force",
                "--config-dir",
                temp_dir,
            ],
        ):
            with patch("sys.stdout") as mock_stdout:
                with patch("sys.stderr"):
                    main()

                    # Check that info message was printed
                    output = mock_stdout.write.call_args_list
                    output_text = "".join([call[0][0] for call in output])
                    assert (
                        "Auto-added http:// to proxy_pass: http://localhost:3000"
                        in output_text
                    )

                    # Check that config file was generated
                    config_path = Path(temp_dir) / "example.com.proxy.conf"
                    assert config_path.exists()

                    # Check that config contains the correct proxy_pass
                    content = config_path.read_text()
                    assert "proxy_pass http://localhost:3000;" in content


def test_cli_dry_run_shows_config_and_docker_command():
    """Test that dry-run mode shows generated config and Docker command."""
    with tempfile.TemporaryDirectory() as temp_dir:
        with patch(
            "sys.argv",
            [
                "enr.py",
                "example.com",
                "http://localhost:3000",
                "--dry-run",
                "--force",
                "--config-dir",
                temp_dir,
            ],
        ):
            with patch("sys.stdout") as mock_stdout:
                with patch("sys.stderr"):
                    main()

                    # Get all output
                    output = mock_stdout.write.call_args_list
                    output_text = "".join([call[0][0] for call in output])

                    # Check that config content is shown
                    assert "📄 Generated nginx configuration:" in output_text
                    assert "server {" in output_text
                    assert "server_name example.com;" in output_text
                    assert "proxy_pass http://localhost:3000;" in output_text

                    # Check that Docker command is shown
                    assert "🐳 Docker command that would be executed:" in output_text
                    assert "docker \\" in output_text
                    assert "--network" in output_text
                    assert "nginx-proxy" in output_text
                    assert "VIRTUAL_HOST=example.com" in output_text
                    assert "nginx:alpine" in output_text

                    # Check that config file was generated
                    config_path = Path(temp_dir) / "example.com.proxy.conf"
                    assert config_path.exists()


def test_cli_dry_run_shows_letsencrypt_vars_for_https():
    """Test that dry-run mode shows Let's Encrypt variables for HTTPS."""
    with tempfile.TemporaryDirectory() as temp_dir:
        with patch(
            "sys.argv",
            [
                "enr.py",
                "example.com",
                "https://api.example.com",
                "--dry-run",
                "--force",
                "--config-dir",
                temp_dir,
            ],
        ):
            with patch("sys.stdout") as mock_stdout:
                with patch("sys.stderr"):
                    main()

                    # Get all output
                    output = mock_stdout.write.call_args_list
                    output_text = "".join([call[0][0] for call in output])

                    # Check that Let's Encrypt variables are shown in Docker command
                    assert "LETSENCRYPT_HOST=example.com" in output_text
                    assert "LETSENCRYPT_EMAIL=443@example.com" in output_text

                    # Check that note about SSL is shown
                    assert (
                        "🔒 Note: Let's Encrypt SSL variables will be added for HTTPS proxy_pass"
                        in output_text
                    )

                    # Check that config file was generated
                    config_path = Path(temp_dir) / "example.com.proxy.conf"
                    assert config_path.exists()
