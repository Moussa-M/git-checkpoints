#!/usr/bin/env python3
"""Setup configuration for git-checkpoints."""

import os
import subprocess
from pathlib import Path
from setuptools import setup, find_packages
from setuptools.command.install import install

# Read the README file
with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()


class PostInstallCommand(install):
    """Post-installation command to run install.sh."""

    def run(self):
        install.run(self)

        # Look for install.sh in the source directory during development
        source_dir = Path(__file__).parent
        install_script = source_dir / "install.sh"

        if install_script.exists():
            print("🚀 Running post-install setup...")
            try:
                # Make sure install.sh is executable
                os.chmod(install_script, 0o755)

                # Run install.sh from the source directory
                result = subprocess.run(
                    [str(install_script)], cwd=str(source_dir), check=False
                )

                if result.returncode == 0:
                    print("✅ Git-checkpoints setup completed successfully!")
                else:
                    print("⚠️ Setup completed with warnings")

            except Exception as e:
                print(f"⚠️ Post-install setup failed: {e}")
                print(
                    "ℹ️ You can manually run 'git-checkpoints resume' to enable auto-checkpointing"
                )
        else:
            print("⚠️ install.sh not found - skipping post-install setup")
            print(
                "ℹ️ Run 'git-checkpoints resume' in your git repos to enable auto-checkpointing"
            )


setup(
    name="git-checkpoints",
    version="2.0.1",
    author="Moussa Mokhtari",
    author_email="me@moussamokhtari.com",
    description="Zero-config, language-agnostic Git snapshots via tags",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/moussa-m/git-checkpoints",
    license="MIT",
    packages=find_packages(),
    data_files=[
        ("", ["git-checkpoints", "install.sh"]),
    ],
    include_package_data=True,
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Version Control",
        "Topic :: Software Development :: Version Control :: Git",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Operating System :: POSIX :: Linux",
        "Operating System :: MacOS",
        "Operating System :: Unix",
    ],
    python_requires=">=3.6",
    entry_points={
        "console_scripts": [
            "git-checkpoints=git_checkpoints.cli:main",
        ],
    },
    cmdclass={
        "install": PostInstallCommand,
    },
    keywords="git version-control checkpoints snapshots tags backup",
    project_urls={
        "Bug Reports": "https://github.com/moussa-m/git-checkpoints/issues",
        "Source": "https://github.com/moussa-m/git-checkpoints",
    },
)
