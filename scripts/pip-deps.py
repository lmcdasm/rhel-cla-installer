#!/usr/bin/env python3
"""Regenerate the pip requirements Hermeto prefetches for the Konflux build.

Sources of truth are the requirements/*.in files; the installer itself is
never built as a Python package. pip-compile turns each one into a flat,
hash-pinned requirements file the hermetic build consumes:

  requirements.in        -> .konflux/pip/requirements-3.12.txt        installer runtime
  requirements-tools.in  -> .konflux/pip/requirements-tools-3.12.txt  zipapp tooling (shiv)
  requirements-build.in  -> .konflux/pip/requirements-build-3.12.txt  PEP 517 build backends
  requirements-build-legacy.in -> .konflux/pip/requirements-build-legacy-3.12.txt
                                  older backend versions capped by some sdists

The hermetic build compiles every wheel from source, so pip needs each
package's PEP 517 build backend (flit-core, hatchling, maturin, ...)
available offline. The build file is a prefetch manifest for Hermeto, which
stores the backends where pip's build isolation finds them via
PIP_FIND_LINKS. Backends are listed by hand: add any new one a pinned sdist
needs. When a build fails with "No matching distribution found for X<N", the
sdist caps a backend below the latest version: pin the older one in
requirements-build-legacy.in.

Hashes let both Hermeto at prefetch time and pip's --require-hashes at
install time verify every artifact.

Run it after changing any requirements/*.in file:

    python3 scripts/pip-deps.py    (or: make pip-deps)

Requires python3.12 on PATH (the builder image version) and network access
to pypi.org; pip-tools is bootstrapped with pip into a
throwaway virtual environment so dependency resolution matches the builder.
"""

import shutil
import subprocess
import sys
import tempfile

from pathlib import Path


# Must match the Python version of the builder image: pip-compile evaluates
# environment markers against the interpreter it runs under.
PYTHON_VERSION = "3.12"
PYTHON_INTERPRETER = shutil.which(f"python{PYTHON_VERSION}")

REPO_ROOT = Path(__file__).resolve().parent.parent
REQUIREMENTS_IN = REPO_ROOT / "requirements" / "requirements.in"
REQUIREMENTS_TOOLS_IN = REPO_ROOT / "requirements" / "requirements-tools.in"
REQUIREMENTS_BUILD_IN = REPO_ROOT / "requirements" / "requirements-build.in"
REQUIREMENTS_BUILD_LEGACY_IN = REPO_ROOT / "requirements" / "requirements-build-legacy.in"
CONSTRAINTS = REPO_ROOT / "requirements" / "constraints.txt"
OUTPUT_DIR = REPO_ROOT / ".konflux" / "pip"


def compile_requirements(pip_compile: Path, source: Path, output: Path) -> None:
    """Resolve and hash-pin the requirements of a .in file into output."""
    subprocess.run(
        [
            str(pip_compile),
            "--quiet",
            "--generate-hashes",
            # pip/setuptools (shiv dependencies) are hidden without this.
            "--allow-unsafe",
            # Header and annotations would embed local paths.
            "--no-header",
            "--no-annotate",
            "--no-strip-extras",
            # Resolve fresh instead of reusing the pins of an existing output file.
            "--upgrade",
            "--constraint",
            str(CONSTRAINTS),
            "--output-file",
            str(output),
            str(source),
        ],
        check=True,
    )


def main() -> None:
    if PYTHON_INTERPRETER is None:
        sys.exit(f"python{PYTHON_VERSION} not found on PATH")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    runtime_file = OUTPUT_DIR / f"requirements-{PYTHON_VERSION}.txt"
    tools_file = OUTPUT_DIR / f"requirements-tools-{PYTHON_VERSION}.txt"
    build_file = OUTPUT_DIR / f"requirements-build-{PYTHON_VERSION}.txt"
    build_legacy_file = OUTPUT_DIR / f"requirements-build-legacy-{PYTHON_VERSION}.txt"

    with tempfile.TemporaryDirectory() as tmp:
        venv_dir = Path(tmp) / "venv"
        print(f"Bootstrapping pip-tools with Python {PYTHON_VERSION}...")
        subprocess.run([PYTHON_INTERPRETER, "-m", "venv", str(venv_dir)], check=True)
        subprocess.run(
            [str(venv_dir / "bin" / "pip"), "install", "--quiet", "pip-tools"],
            check=True,
        )

        print("Compiling installer runtime requirements...")
        compile_requirements(venv_dir / "bin" / "pip-compile", REQUIREMENTS_IN, runtime_file)

        print("Compiling zipapp build tooling...")
        compile_requirements(venv_dir / "bin" / "pip-compile", REQUIREMENTS_TOOLS_IN, tools_file)

        print("Compiling PEP 517 build backends...")
        compile_requirements(venv_dir / "bin" / "pip-compile", REQUIREMENTS_BUILD_IN, build_file)

        print("Compiling legacy PEP 517 build backends...")
        compile_requirements(
            venv_dir / "bin" / "pip-compile", REQUIREMENTS_BUILD_LEGACY_IN, build_legacy_file
        )

    for path in sorted(OUTPUT_DIR.glob("*.txt")):
        pkg_count = sum(1 for line in path.read_text().splitlines() if line and line[0].isalpha())
        print(f"Wrote {path.relative_to(REPO_ROOT)} ({pkg_count} packages)")

    print("Remember to commit the regenerated files.")


if __name__ == "__main__":
    main()
