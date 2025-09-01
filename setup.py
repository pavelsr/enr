#!/usr/bin/env python3
"""Setup script for ENR package."""

from setuptools import find_packages, setup

if __name__ == "__main__":
    setup(
        name="enr",
        version="0.1.0",
        description="CLI utility for easy nginx reverse proxy configuration with automatic redirect handling",
        author="Pavel Serikov",
        author_email="devpasha@proton.me",
        packages=find_packages(),
        install_requires=[],
        entry_points={
            "console_scripts": [
                "enr=enr.cli:main",
            ],
        },
        python_requires=">=3.10",
        classifiers=[
            "Development Status :: 4 - Beta",
            "Intended Audience :: Developers",
            "Intended Audience :: System Administrators",
            "License :: OSI Approved :: MIT License",
            "Operating System :: OS Independent",
            "Programming Language :: Python :: 3",
            "Programming Language :: Python :: 3.10",
            "Programming Language :: Python :: 3.11",
            "Programming Language :: Python :: 3.12",
            "Topic :: Internet :: WWW/HTTP :: HTTP Servers",
            "Topic :: System :: Systems Administration",
            "Topic :: Utilities",
        ],
        keywords=[
            "nginx",
            "reverse-proxy",
            "docker",
            "cli",
            "devops",
            "proxy",
            "redirect",
            "auto-redirect",
        ],
        url="https://github.com/pavelsr/enr",
        project_urls={
            "Homepage": "https://github.com/pavelsr/enr",
            "Repository": "https://github.com/pavelsr/enr",
        },
    )
