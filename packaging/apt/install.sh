#!/bin/sh
set -eu

repo_url="${BUILDIO_APT_URL:-https://buildio.github.io/cli/apt}"
key_url="${repo_url}/gpg.key"
keyring="/usr/share/keyrings/buildio-archive-keyring.gpg"
source_list="/etc/apt/sources.list.d/buildio-cli.list"

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    if ! command -v sudo >/dev/null 2>&1; then
      echo "This installer needs root privileges. Re-run as root or install sudo." >&2
      exit 1
    fi
    sudo "$@"
  fi
}

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This installer only supports apt-based Linux distributions." >&2
  exit 1
fi

if ! command -v dpkg >/dev/null 2>&1; then
  echo "dpkg is required to detect the system architecture." >&2
  exit 1
fi

arch="$(dpkg --print-architecture)"
case "$arch" in
  amd64) ;;
  *)
    echo "Unsupported architecture: $arch. Build.io CLI APT packages currently support amd64." >&2
    exit 1
    ;;
esac

tmpdir="$(mktemp -d)"
cleanup() {
  rm -f \
    "$tmpdir/buildio-archive-keyring.asc" \
    "$tmpdir/buildio-archive-keyring.gpg" \
    "$tmpdir/buildio-cli.list"
  rmdir "$tmpdir"
}
trap cleanup EXIT

run_as_root apt-get update
run_as_root apt-get install -y ca-certificates curl gnupg

curl -fsSL "$key_url" -o "$tmpdir/buildio-archive-keyring.asc"
gpg --batch --yes --dearmor -o "$tmpdir/buildio-archive-keyring.gpg" "$tmpdir/buildio-archive-keyring.asc"
run_as_root install -m 0644 "$tmpdir/buildio-archive-keyring.gpg" "$keyring"

cat > "$tmpdir/buildio-cli.list" <<EOF
deb [arch=amd64 signed-by=$keyring] $repo_url stable main
EOF
run_as_root install -m 0644 "$tmpdir/buildio-cli.list" "$source_list"

run_as_root apt-get update
run_as_root apt-get install -y buildio-archive-keyring bld

cat <<EOF
Build.io CLI installed.

If an older manual install exists at /usr/local/bin/bld, remove it or ensure /usr/bin appears first in PATH.
EOF
