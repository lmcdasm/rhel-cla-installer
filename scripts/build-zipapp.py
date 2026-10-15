#!/usr/bin/env python3
import shutil
import subprocess
import venv

from pathlib import Path


def create_venv(name: str) -> Path:
    target_venv = Path("/opt/venvs") / name
    venv.create(target_venv, clear=True, with_pip=True)

    return target_venv


def main():
    # Install shiv
    print("Installing build tools...")
    build_venv = create_venv("tools")
    build_venv_python = build_venv / "bin" / "python"
    subprocess.check_call([build_venv_python, "-m", "pip", "install", "-r", "/opt/setup/requirements-build-3.12.txt"])

    # Build Ansible venv
    print("Building installer...")
    ansible_venv = create_venv("ansible")
    ansible_site_packages = ansible_venv / "lib" / "python3.12" / "site-packages"
    ansible_venv_python = ansible_venv / "bin" / "python"
    subprocess.check_call([ansible_venv_python, "-m", "pip", "install", "-r", "/opt/setup/requirements-3.12.txt"])
    shutil.copytree("/opt/setup/collections/ansible_collections", ansible_site_packages / "ansible_collections")

    # Build zipapp
    print("Packaging installer...")
    shiv = build_venv / "bin" / "shiv"
    # fmt: off
    subprocess.check_call([
        shiv, "--site-packages",
        ansible_site_packages,
        "--console-script", "ansible-playbook",
        "--output-file", "/opt/rhel-cla-installer",
    ])
    # fmt: on

    print("Done!")


if __name__ == "__main__":
    main()
