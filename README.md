ENR = Easy Nginx Redirects

[![CLI Tool](https://img.shields.io/badge/CLI-Tool-green.svg)](https://github.com/pavelsr/enr)
[![Made with Pure Python3](https://img.shields.io/badge/Made%20with-Pure%20Python3-FFCC33.svg?logo=python&logoColor=white)](https://docs.python.org/3/)
[![Nginx as Proxy](https://img.shields.io/badge/Nginx-as%20Proxy-009639.svg?logo=nginx&logoColor=white)](https://nginx.org/)
[![Docker as Deploy](https://img.shields.io/badge/Docker-as%20Deploy-blue.svg?logo=docker&logoColor=white)](https://www.docker.com/)
[![MIT license](https://img.shields.io/badge/MIT-license-9933CC.svg)](https://opensource.org/licenses/MIT)
[![PyPI version](https://img.shields.io/badge/PyPI-version-FFCC33.svg)](https://pypi.org/project/enr/)
[![Contact Developer](https://img.shields.io/badge/Contact-Developer-9933CC.svg?logo=telegram&logoColor=white)](https://t.me/serikoff)

CLI utility for quick & easy generating nginx configuration and running Docker containers with nginx reverse proxy.

Uses only Python standard library without external dependencies. So the utility works immediately after copying files - does not require installation of additional Python packages.

This utility demonstrates the capabilities of nginx's [ngx_http_proxy_module](https://nginx.org/en/docs/http/ngx_http_proxy_module.html) using directives: `proxy_pass`, `proxy_pass_header`, `proxy_intercept_errors`, `proxy_ssl_verify`. These are the specific directives currently implemented, but `ngx_http_proxy_module` module offers many more options. The project serves as an example of a Python wrapper for automatic Docker container configuration and nginx-proxy integration, as well as building Python modules into a single executable script. You can fork this project and customize the nginx and Docker templates for your needs. Pull requests are welcome.

<!-- Created by https://github.com/ekalinin/github-markdown-toc (gh-md-toc README.md)-->

Table of Contents
=================

* [Table of Contents](#table-of-contents)
* [Use Cases](#use-cases)
* [Installation](#installation)
   * [Quick Installation](#quick-installation)
   * [Other installation ways](#other-installation-ways)
      * [Installation from source code](#installation-from-source-code)
      * [Notes about pipx](#notes-about-pipx)
      * [If GitHub is blocked in your network](#if-github-is-blocked-in-your-network)
* [Usage](#usage)
   * [nginx-proxy Compatibility](#nginx-proxy-compatibility)
      * [Integration with nginx-proxy](#integration-with-nginx-proxy)
      * [Quick nginx-proxy deployment](#quick-nginx-proxy-deployment)
* [Under the Hood](#under-the-hood)
   * [Requirements](#requirements)
   * [Dependencies](#dependencies)
   * [Generated Nginx Configuration](#generated-nginx-configuration)
   * [Docker Container Running](#docker-container-running)
* [Features &amp; Roadmap](#features--roadmap)
* [Development &amp; Contributing](#development--contributing)
   * [Version Management](#version-management)
      * [Versioning F.A.Q.](#versioning-faq)
      * [Versioning scheme](#versioning-scheme)
   * [Pre-commit Hooks](#pre-commit-hooks)


<!-- Created by https://github.com/ekalinin/github-markdown-toc (gh-md-toc README.md) -->

# Use Cases

- 🐳 **One-click proxying for any local (Dockerized and non-Dockerized) or remote HTTP or HTTPS service**. This tools runs proxy service as single docker container that is convenient to manage. Support docker networks and hostnames, `host.docker.internal` domain
- 🔒 **Secure Access to Any Service**. Make any web service accessible through HTTPS with just one command, even if it doesn't have security certificates
- 🏗️ **Website Constructor Integration**. Free domain binding for website builders like Tilda, Wix, Webflow, etc. Best for fully static sites, forms may require additional configuration
- 🔗 **Custom Subdomain Links**. Create short, easy-to-remember subdomain links using your own domain name instead of generic shortener services
- 😉 **Your Own Everything**. PRs and forks are welcome

# Installation

## Quick Installation

Since it uses only Python standard library without external dependencies you can install it via:

```bash
curl -fsSL --compressed https://raw.githubusercontent.com/pavelsr/enr/main/enr.pyz > /usr/local/bin/enr && \
    chmod +x /usr/local/bin/enr
```

or you can install it as regular Python module:

```shell
# pipx (recommended)
pipx install enr    # or from GitHub:
pipx install git+https://github.com/pavelsr/enr.git@main

# pip
pip install enr     # or from GitHub:
pip install git+https://github.com/pavelsr/enr.git@main
```

## Other installation ways

<details>
<summary>Other installation ways</summary>

### Installation from source code

```bash
git clone https://github.com/pavelsr/enr.git
cd enr
# Run without installation
./enr.py example.com http://localhost:3000
# Editable install (convenient for test and development):
pip install -e .
# Install development dependencies
pip install -e ".[dev]"
# Install using flit in development mode
flit install --symlink
# Creates enr.pyz from modules:
make build  # Creates enr.pyz from modules
# Or use flit directly
flit build
```

### Notes about pipx 

Since this is a CLI utility, it's recommended to install it using pipx to avoid conflicts with other Python packages:

```bash
# Install pipx if not already installed
python -m pip install --user pipx
python -m pipx ensurepath

# Install ENR
pipx install enr
```

**Advantages of pipx installation:**
- ✅ Isolated environment - no conflicts with other Python packages
- ✅ Easy updates - `pipx upgrade enr`
- ✅ Easy uninstall - `pipx uninstall enr`
- ✅ Global availability - `enr` command available everywhere

### If GitHub is blocked in your network

You can copy the project manually using scp or rsync from a machine where GitHub is NOT blocked:

```bash
# Using scp, only enr.pyz
scp ./enr.pyz user@host.example.com:/usr/local/bin/enr

# Using scp, whole source code
ssh user@host.example.com "mkdir -p ~/enr" && scp -r * user@host.example.com:~/enr/

# Using rsync, whole source code (requires rsync on both machines)
rsync -avz . user@host.example.com:~/enr/
```

**Note**: Replace `user@host.example.com` with your actual server details. The rsync command automatically creates the 'enr' folder if it doesn't exist.

</details>


# Usage

```
usage: enr [-h] [--port PORT] [--container-name CONTAINER_NAME] [--network NETWORK] [--config-dir CONFIG_DIR] [--dry-run] [--force] [--with-letsencrypt] [--version] server_name proxy_pass

positional arguments:
  server_name           Domain name for the server
  proxy_pass            Upstream server URL (e.g., http://localhost:3000)

options:
  -h, --help            show this help message and exit
  --port PORT, -p PORT  Port to listen on (default: 80)
  --container-name CONTAINER_NAME, -n CONTAINER_NAME
                        Docker container name (defaults to server_name)
  --network NETWORK     Docker network name (default: nginx-proxy)
  --config-dir CONFIG_DIR, -d CONFIG_DIR
                        Directory to save nginx config (default: current directory)
  --dry-run             Generate config only, don't run Docker container
  --force, -f           Force overwrite existing config file
  --with-letsencrypt    Automatically add Let's Encrypt environment variables for SSL support
  --version             Show version and exit

Examples:
enr example.com http://<container_name>:3000
enr example.com http://host.docker.internal:8000 --port 3000
enr example.com http://host.docker.internal:8000 --with-letsencrypt
enr shop.example.com https://marketplace.example/seller/<seller_id>
enr example.com https://example.tilda.ws --container-name my-tilda-proxy
enr test.com http://localhost:5000 --dry-run --config-dir ./configs --force
```

## nginx-proxy Compatibility

ENR is specifically designed to work with [nginx-proxy](https://github.com/nginx-proxy/nginx-proxy) - a popular solution for automatic Docker container proxying. ENR automatically:

- Generates compatible nginx configurations
- Runs containers in the `nginx-proxy` network (by default)
- Sets the `VIRTUAL_HOST` environment variable for automatic discovery
- Adds Let's Encrypt variables for SSL certificates when using HTTPS

### Integration with nginx-proxy

```bash
# Start nginx-proxy (if not already running)
docker run -d -p 80:80 -p 443:443 \
  --name nginx-proxy \
  --restart always \
  -v /var/run/docker.sock:/tmp/docker.sock:ro \
  nginxproxy/nginx-proxy

# Imagine that you have non-dockerized service running at 8000 port locally

# Using ENR with nginx-proxy
./enr.py example.com http://host.docker.internal:8000
```

### Quick nginx-proxy deployment

For a complete example of nginx-proxy deployment with Let\x27s Encrypt support, see:
**🔗 https://gitlab.com/pavelsr/nginx-proxy**

This repository contains ready-to-use scripts for quick deployment of nginx-proxy with automatic SSL certificate management.

# Under the Hood

Some Technical Overview about Architecture and Implementation Details

## Requirements

- Python 3.11+ (recommended), 3.10+ (minimum)
- Docker

For full functionality, it is recommended to use:

- **[nginx-proxy](https://github.com/nginx-proxy/nginx-proxy)** - automatic Docker container proxying
- **[nginx-proxy-letsencrypt](https://github.com/nginx-proxy/acme-companion)** - automatic Let's Encrypt SSL certificates

## Dependencies

**The project has no external dependencies** - uses only Python standard library:

- `argparse` - command line argument processing
- `pathlib` - file system path operations
- `subprocess` - running Docker commands
- `str.format()` - nginx configuration formatting (instead of jinja2)
- `zipapp` - building single script (instead of stickytape or PyInstaller)

## Generated Nginx Configuration

The utility creates an nginx configuration of the following type:

```nginx
server {
  server_name example.com;
  listen 80;

  location / {
    proxy_pass http://localhost:3000;
    proxy_pass_header Host;
    proxy_intercept_errors on;
    error_page 301 302 307 = @handle_redirect;
    # recursive_error_pages on;
  }

  location @handle_redirect {
    set $saved_redirect_location '$upstream_http_location';
    proxy_pass $saved_redirect_location;
  }
}
```

## Docker Container Running

After generating the configuration, the utility runs a Docker container with the command:

```bash
# For HTTP
docker run --network nginx-proxy \
  -e VIRTUAL_HOST=example.com \
  -v $(pwd)/example.com.proxy.conf:/etc/nginx/conf.d/default.conf \
  --name example.com \
  -d --restart always nginx:alpine

# For HTTPS (Let's Encrypt variables are automatically added)
docker run --network nginx-proxy \
  -e VIRTUAL_HOST=example.com \
  -e LETSENCRYPT_HOST=example.com \
  -e LETSENCRYPT_EMAIL=443@example.com \
  -v $(pwd)/example.com.proxy.conf:/etc/nginx/conf.d/default.conf \
  --name example.com \
  -d --restart always nginx:alpine
```

# Features & Roadmap

Implemented Features:

- [x] **Easy to use** - one command to set up reverse proxy
- [x] **No external dependencies** - only Python needed (recommended version 3.11)
- [x] **Single script** - can be installed with one curl command, without git/pip/pipx
- [x] **Docker integration** - automatic container running
- [x] **nginx-proxy integration** - nginx-proxy automatically discover containers by `VIRTUAL_HOST`
- [x] **Automatic protocol addition** - automatically adds `http://` to domains without protocol
- [x] **Automatic arguments addition** - automatically adds arguments for support `host.docker.internal`
- [x] **Automatic Let's Encrypt SSL support** - automatically adds environment variables for HTTPS
- [x] **Named configurations** - files are created as `{server_name}.proxy.conf` for better organization
- [x] **Single-source versionin** - `__init__.py`
- [x] **Flit-based build system**
- [x] **Zipapp-based single-file build**

TODO (Roadmap):

- [ ] **Nginx configs as named templates**
- [ ] **More high-level tests**
- [ ] **traefik and other proxy servers integration**

# Development & Contributing

All necessary development commands are available in the Makefile following best practices. To view the complete list of commands, run:

```bash
make help
```

<details>
<summary>Common Makefile commands</summary>


```bash
# Install development dependencies
make install-dev

# Install pre-commit hooks
make pre-commit-install

# Run all checks (formatting, linting, tests)
make check

# Or separately:
make format    # Code formatting
make lint      # Style checking
make test      # Run tests

# Pre-commit hooks
make pre-commit-run    # Manual pre-commit hooks run
make pre-commit-clean  # Clean pre-commit cache

# Clean temporary files
make clean
```
</details>


## Git Guidelines

Before submitting a PR:

1. **Squash your commits** into a single, meaningful commit. E.g.

   ```bash
   git reset --soft HEAD~42
   git commit -m "feat: add new nginx configuration feature"
   ```

2. **Use descriptive commit messages** that explain what the change does

   E.g.
   ```bash
   git commit -m "fix: resolve docker container startup issue (#456)"
   ```

   **Good practice**: Include issue number if one exists (as shown in the example above)

FYI: I prefer [trunk-based development](https://trunkbaseddevelopment.com/) rather than [gitflow branching model](https://nvie.com/posts/a-successful-git-branching-model/)


## Version Management

**To change version ONLY ONE STEP REQUIRED:** Update version in `__init__.py`: `__version__ = "x.y.z"`

**That's it!** All other files automatically get the new version when you run:
- `make build` - builds single script with current version
- `make build-dist` - builds distribution packages with current version

<details>
<summary>Benefits of this approach</summary>

- **Single source of truth**: Version managed in ONE file only (`__init__.py`)
- **Automatic propagation**: All other files automatically get the version from this file
- **Flit dynamic versioning**: Uses flit's built-in `dynamic = ["version"]` feature
- **No git dependency**: Version management works independently of git tags
- **No manual sync needed**: Version is automatically read from module during build
</details>


<details>
<summary>Files that automatically get the version</summary>

```
pyenr/
├── enr/
│ └── init.py # ← MAIN VERSION FILE (change here ONLY)
├── pyproject.toml # ← gets version automatically via flit dynamic
├── setup.py # ← imports version from enr.init (legacy compatibility)
├── enr.pyz # ← single executable script (built via make build)
└── dist/ # ← packages get version automatically
```

</details>

### Versioning F.A.Q.

**Q: How to check current version?**
A: Run `python -c "import enr; print(enr.__version__)"`

**Q: Version didn't update after changing version.py?**
A: Make sure to run `make build` or `make build-dist` after changing the version. Flit will automatically read the new version.

**Q: Flit build failed?**
A: Make sure all files are committed to git, as flit requires a clean git state.

### Versioning scheme

This project follows [Semantic Versioning](https://semver.org/)

## Pre-commit Hooks

The project uses pre-commit hooks for automatic code quality checking before each commit

**What is automatically checked:**
- ✅ Single script build (`make build`)
- ✅ Code formatting (Black)
- ✅ Style checking (ruff)
- ✅ Test running (pytest)
- ✅ Automatic addition of changed `enr.pyz` to commit
