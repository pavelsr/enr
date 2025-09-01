"""Tests for nginx configuration generation."""

import tempfile
from pathlib import Path

from enr.nginx import generate_nginx_config


def test_generate_nginx_config_basic():
    """Test basic nginx config generation."""
    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = Path(temp_dir) / "default.conf"

        generate_nginx_config(
            server_name="example.com",
            proxy_pass="http://localhost:3000",
            output_path=config_path,
        )

        assert config_path.exists()

        content = config_path.read_text()
        assert "server_name example.com;" in content
        assert "proxy_pass http://localhost:3000;" in content
        assert "listen 80;" in content


def test_generate_nginx_config_custom_port():
    """Test nginx config generation with custom port."""
    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = Path(temp_dir) / "default.conf"

        generate_nginx_config(
            server_name="example.com",
            proxy_pass="http://localhost:3000",
            port=8080,
            output_path=config_path,
        )

        content = config_path.read_text()
        assert "listen 8080;" in content


def test_generate_nginx_config_redirect_handling():
    """Test redirect handling is included in config."""
    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = Path(temp_dir) / "default.conf"

        generate_nginx_config(
            server_name="example.com",
            proxy_pass="http://localhost:3000",
            output_path=config_path,
        )

        content = config_path.read_text()
        assert "error_page 301 302 307 = @handle_redirect;" in content
        assert "location @handle_redirect {" in content
        assert "set $saved_redirect_location '$upstream_http_location';" in content
        assert "proxy_pass $saved_redirect_location;" in content


def test_generate_nginx_config_creates_directories():
    """Test that directories are created if they don't exist."""
    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = Path(temp_dir) / "subdir" / "nested" / "default.conf"

        generate_nginx_config(
            server_name="example.com",
            proxy_pass="http://localhost:3000",
            output_path=config_path,
        )

        assert config_path.exists()
        assert config_path.parent.exists()


def test_generate_nginx_config_string_path():
    """Test that string paths are handled correctly."""
    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = str(Path(temp_dir) / "default.conf")

        generate_nginx_config(
            server_name="example.com",
            proxy_pass="http://localhost:3000",
            output_path=config_path,
        )

        assert Path(config_path).exists()
