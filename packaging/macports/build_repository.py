#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
import sys
import tarfile
from pathlib import Path

PORT_CATEGORY = "sysutils"
PORT_NAME = "bld"
REQUIRED_ARCHES = ("x86_64", "arm64")
ASSET_DISTNAMES = {
    "x86_64": "bld-darwin-amd64",
    "arm64": "bld-darwin-arm64",
}


def digest(path: Path, algorithm: str) -> str:
    h = hashlib.new(algorithm)
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def validate_version(version: str) -> None:
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise SystemExit(f"version must be MAJOR.MINOR.PATCH, got {version!r}")


def parse_asset(value: str) -> tuple[str, Path]:
    arch, sep, path = value.partition("=")
    if not sep or arch not in REQUIRED_ARCHES or not path:
        expected = ", ".join(f"{arch}=PATH" for arch in REQUIRED_ARCHES)
        raise argparse.ArgumentTypeError(f"asset must be one of: {expected}")
    return arch, Path(path)


def validate_binary_asset(path: Path, arch: str) -> None:
    distname = ASSET_DISTNAMES[arch]
    expected_binary = f"{distname}/bld"
    with tarfile.open(path, "r:gz") as tar:
        members = {member.name: member for member in tar.getmembers()}

    binary = members.get(expected_binary)
    if binary is None:
        raise SystemExit(f"{path} is missing {expected_binary}")
    if not binary.isfile():
        raise SystemExit(f"{path}:{expected_binary} is not a file")
    if binary.mode & 0o111 == 0:
        raise SystemExit(f"{path}:{expected_binary} is not executable")


def asset_replacements(assets: dict[str, Path]) -> dict[str, str]:
    replacements: dict[str, str] = {}
    for arch, path in assets.items():
        token_prefix = "X86_64" if arch == "x86_64" else "ARM64"
        replacements[f"@{token_prefix}_RMD160@"] = digest(path, "ripemd160")
        replacements[f"@{token_prefix}_SHA256@"] = digest(path, "sha256")
        replacements[f"@{token_prefix}_SIZE@"] = str(path.stat().st_size)
    return replacements


def render_portfile(template_path: Path, version: str, assets: dict[str, Path]) -> str:
    template = template_path.read_text()
    replacements = {"@VERSION@": version, **asset_replacements(assets)}
    for token, value in replacements.items():
        template = template.replace(token, value)

    unresolved = sorted(set(re.findall(r"@[A-Z0-9_]+@", template)))
    if unresolved:
        raise SystemExit(f"unresolved Portfile template tokens: {', '.join(unresolved)}")
    return template


def write_ports_tar(output_dir: Path, portfile: str) -> Path:
    tree_root = output_dir / "ports"
    port_dir = tree_root / PORT_CATEGORY / PORT_NAME
    port_dir.mkdir(parents=True, exist_ok=True)
    (port_dir / "Portfile").write_text(portfile)

    tar_path = output_dir / "ports.tar"
    if tar_path.exists():
        tar_path.unlink()

    with tarfile.open(tar_path, "w") as tar:
        tar.add(tree_root, arcname="ports")
    return tar_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the Build.io MacPorts repository snapshot.")
    parser.add_argument("--version", required=True, help="CLI version without the leading v.")
    parser.add_argument(
        "--asset",
        action="append",
        type=parse_asset,
        required=True,
        help="Prebuilt binary tarball as ARCH=PATH. Required for x86_64 and arm64.",
    )
    parser.add_argument("--output", required=True, type=Path, help="Directory that will receive ports.tar.")
    parser.add_argument(
        "--template",
        type=Path,
        default=Path("packaging/macports/Portfile.tpl"),
        help="Portfile template path.",
    )
    args = parser.parse_args()

    validate_version(args.version)

    assets: dict[str, Path] = {}
    for arch, path in args.asset:
        if arch in assets:
            raise SystemExit(f"duplicate asset for {arch}")
        resolved = path.resolve()
        if not resolved.is_file():
            raise SystemExit(f"asset does not exist: {resolved}")
        validate_binary_asset(resolved, arch)
        assets[arch] = resolved

    missing = [arch for arch in REQUIRED_ARCHES if arch not in assets]
    if missing:
        raise SystemExit(f"missing assets for: {', '.join(missing)}")

    args.output.mkdir(parents=True, exist_ok=True)
    portfile = render_portfile(args.template, args.version, assets)
    tar_path = write_ports_tar(args.output, portfile)

    print(f"Wrote {tar_path}")
    for arch in REQUIRED_ARCHES:
        print(f"{arch} asset: {assets[arch]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
