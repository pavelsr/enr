"""Tests for Docker container management."""

import tempfile
from pathlib import Path
from unittest.mock import patch

from enr.docker import build_docker_command, run_nginx_container


def test_build_docker_command_basic():
    """Test basic Docker command building."""
    config_path = Path("/tmp/test.conf")

    cmd = build_docker_command(
        server_name="example.com",
        container_name="test-container",
        network="nginx-proxy",
        config_path=config_path,
        proxy_pass="http://localhost:3000",
    )

    assert cmd[0] == "docker"
    assert cmd[1] == "run"
    assert "--network" in cmd
    assert "nginx-proxy" in cmd
    assert "VIRTUAL_HOST=example.com" in cmd
    assert "nginx:alpine" in cmd
    assert "test-container" in cmd


def test_build_docker_command_with_https():
    """Test Docker command building with HTTPS."""
    config_path = Path("/tmp/test.conf")

    cmd = build_docker_command(
        server_name="example.com",
        container_name="test-container",
        network="nginx-proxy",
        config_path=config_path,
        proxy_pass="https://api.example.com",
    )

    assert "LETSENCRYPT_HOST=example.com" in cmd
    assert "LETSENCRYPT_EMAIL=443@example.com" in cmd


def test_build_docker_command_without_proxy_pass():
    """Test Docker command building without proxy_pass."""
    config_path = Path("/tmp/test.conf")

    cmd = build_docker_command(
        server_name="example.com",
        container_name="test-container",
        network="nginx-proxy",
        config_path=config_path,
        proxy_pass=None,
    )

    # Should not include Let's Encrypt variables
    assert "LETSENCRYPT_HOST" not in cmd
    assert "LETSENCRYPT_EMAIL" not in cmd


def test_build_docker_command_custom_network():
    """Test Docker command building with custom network."""
    config_path = Path("/tmp/test.conf")

    cmd = build_docker_command(
        server_name="example.com",
        container_name="test-container",
        network="custom-network",
        config_path=config_path,
        proxy_pass="http://localhost:3000",
    )

    assert "--network" in cmd
    assert "custom-network" in cmd


def test_run_nginx_container_with_https_adds_letsencrypt_vars():
    """Test adding Let's Encrypt variables for HTTPS in run_nginx_container."""
    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = Path(temp_dir) / "test.conf"
        config_path.write_text("test config")

        with patch("subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = ""

            run_nginx_container(
                server_name="example.com",
                container_name="test-container",
                config_path=config_path,
                proxy_pass="https://api.example.com",
            )

            # Check that Docker command was called
            assert mock_run.called

            # Get the command that was passed to subprocess.run
            call_args = mock_run.call_args_list
            docker_cmd = call_args[-1][0][0]  # Last call, first argument

            # Check that Let's Encrypt variables are included
            assert "LETSENCRYPT_HOST=example.com" in docker_cmd
            assert "LETSENCRYPT_EMAIL=443@example.com" in docker_cmd


def test_run_nginx_container_with_http_no_letsencrypt_vars():
    """Test not adding Let's Encrypt variables for HTTP in run_nginx_container."""
    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = Path(temp_dir) / "test.conf"
        config_path.write_text("test config")

        with patch("subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = ""

            run_nginx_container(
                server_name="example.com",
                container_name="test-container",
                config_path=config_path,
                proxy_pass="http://localhost:3000",
            )

            # Check that Docker command was called
            assert mock_run.called

            # Get the command that was passed to subprocess.run
            call_args = mock_run.call_args_list
            docker_cmd = call_args[-1][0][0]  # Last call, first argument

            # Check that Let's Encrypt variables are not included
            assert "LETSENCRYPT_HOST" not in docker_cmd
            assert "LETSENCRYPT_EMAIL" not in docker_cmd


def test_run_nginx_container_without_proxy_pass_no_letsencrypt_vars():
    """Test no Let's Encrypt variables without proxy_pass in run_nginx_container."""
    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = Path(temp_dir) / "test.conf"
        config_path.write_text("test config")

        with patch("subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = ""

            run_nginx_container(
                server_name="example.com",
                container_name="test-container",
                config_path=config_path,
                proxy_pass=None,
            )

            # Check that Docker command was called
            assert mock_run.called

            # Get the command that was passed to subprocess.run
            call_args = mock_run.call_args_list
            docker_cmd = call_args[-1][0][0]  # Last call, first argument

            # Check that Let's Encrypt variables are not included
            assert "LETSENCRYPT_HOST" not in docker_cmd
            assert "LETSENCRYPT_EMAIL" not in docker_cmd


def test_run_nginx_container_removes_existing_container():
    """Test that run_nginx_container removes existing container."""
    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = Path(temp_dir) / "test.conf"
        config_path.write_text("test config")

        with patch("subprocess.run") as mock_run:
            # First call (check container) returns existing container
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = "test-container"

            run_nginx_container(
                server_name="example.com",
                container_name="test-container",
                config_path=config_path,
            )

            # Check that docker rm was called
            call_args = [call[0][0] for call in mock_run.call_args_list]
            assert ["docker", "rm", "-f", "test-container"] in call_args


def test_run_nginx_container_environment_variables_order():
    """Test that environment variables are in correct order."""
    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = Path(temp_dir) / "test.conf"
        config_path.write_text("test config")

        with patch("subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = ""

            run_nginx_container(
                server_name="example.com",
                container_name="test-container",
                config_path=config_path,
                proxy_pass="https://api.example.com",
            )

            # Get the Docker command
            call_args = mock_run.call_args_list
            docker_cmd = call_args[-1][0][0]  # Last call, first argument

            # Check order: VIRTUAL_HOST should come before Let's Encrypt variables
            virtual_host_index = docker_cmd.index("VIRTUAL_HOST=example.com")
            letsencrypt_host_index = docker_cmd.index("LETSENCRYPT_HOST=example.com")
            letsencrypt_email_index = docker_cmd.index(
                "LETSENCRYPT_EMAIL=443@example.com"
            )

            assert virtual_host_index < letsencrypt_host_index
            assert letsencrypt_host_index < letsencrypt_email_index
