"""
Conversion of a Word document to PDF with LibreOffice.
"""
import glob
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TIMEOUT = 180

SOFFICE_NAMES = ["soffice.com", "soffice", "libreoffice"]

SOFFICE_PATHS = [
    "/Applications/LibreOffice.app/Contents/MacOS/soffice",
    "~/Applications/LibreOffice.app/Contents/MacOS/soffice",
    r"C:\Program Files\LibreOffice\program\soffice.com",
    r"C:\Program Files (x86)\LibreOffice\program\soffice.com",
    "/usr/bin/soffice",
    "/usr/bin/libreoffice",
    "/opt/libreoffice*/program/soffice",
    "/snap/bin/libreoffice",
]


class DocxToPdfConverter:
    """
    Converter of documents, that uses the LibreOffice engine.
    """

    def __init__(self):
        self.soffice = self.find_soffice()

    def __call__(self, source, target):
        """
        Converts the document to PDF.

        Args:
            source (Path): Path of the document.
            target (Path): Path of the created PDF.
        """
        self.export(source, target, "pdf")

    def find_soffice(self):
        """
        Finds LibreOffice, that can be executed. A launcher can
        exist on the PATH, while the application is not installed.

        Returns:
            str: Path of the working LibreOffice executable.
        """
        candidates = [shutil.which(name) for name in SOFFICE_NAMES]

        for pattern in SOFFICE_PATHS:
            candidates.extend(glob.glob(os.path.expanduser(pattern)))

        for path in candidates:
            if path and self.is_working(path):
                return path

        raise RuntimeError(
            "LibreOffice not found. Install it from https://www.libreoffice.org/"
        )

    def is_working(self, path):
        try:
            result = subprocess.run(
                [path, "--version"],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                timeout=TIMEOUT
            )
        except (OSError, subprocess.TimeoutExpired):
            return False

        return result.returncode == 0

    def export(self, source, target, file_format):
        """
        Exports the document with a separate LibreOffice profile.

        Args:
            source (Path): Path of the document.
            target (Path): Path of the created file.
            file_format (str): Extension of the created file.
        """
        with tempfile.TemporaryDirectory() as work:
            profile = Path(work, "profile").resolve().as_uri()
            out_dir = Path(work, "out")
            out_dir.mkdir()

            result = subprocess.run(
                [
                    self.soffice,
                    f"-env:UserInstallation={profile}",
                    "--headless",
                    "--convert-to", file_format,
                    "--outdir", str(out_dir),
                    str(source)
                ],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                errors="replace",
                timeout=TIMEOUT
            )

            produced = out_dir / f"{source.stem}.{file_format}"

            if result.returncode != 0 or not produced.is_file():
                raise RuntimeError(f"Conversion failed: {result.stderr.strip()}")
            if produced.stat().st_size == 0:
                raise RuntimeError(f"LibreOffice produced an empty {file_format} file")

            shutil.move(str(produced), str(target))


def run_cli(args, converter_class, suffix):
    """
    Runs a converter from the command line.

    Args:
        args (str[]): Command line arguments.
        converter_class (type): Class of the converter.
        suffix (str): Required extension of the source file.

    Returns:
        int: Exit code.
    """
    sys.stdout.reconfigure(errors="replace")

    force = "--force" in args
    paths = [arg for arg in args if arg != "--force"]

    if len(paths) != 1 or paths[0].startswith("--"):
        print(f"Usage: python {Path(sys.argv[0]).name} <input{suffix}> [--force]")
        return 2

    source = Path(paths[0]).resolve()
    target = source.with_suffix(".pdf")

    if not source.is_file():
        print(f"File not found: {source}")
        return 1
    if source.suffix.lower() != suffix:
        print(f"Input must be a {suffix} file")
        return 1
    if target.exists() and not force:
        print(f"PDF already exists, use --force to overwrite: {target}")
        return 1

    try:
        converter = converter_class()
        converter(source, target)
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(error)
        return 1

    print(f"Source: {source}")
    print(f"PDF: {target}")
    return 0


if __name__ == "__main__":
    sys.exit(run_cli(sys.argv[1:], DocxToPdfConverter, ".docx"))
