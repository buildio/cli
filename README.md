# Build CLI

## Install
### macOS 15+ / Linux (Homebrew)

Install Homebrew and setup envs:

```sh
brew -v||eval "$(bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"|tee /dev/fd/2|grep '^    [es]')"
```

```sh
brew install buildio/cli/bld;brew trust buildio/cli
```

### macOS (MacPorts)

MacPorts verifies HTTPS ports tree snapshots, so trust the Build.io ports key once before adding the source:

```bash
curl -fsSL https://buildio.github.io/cli/macports/buildio-ports.pub | sudo tee /opt/local/share/macports/buildio-ports.pub >/dev/null
echo /opt/local/share/macports/buildio-ports.pub | sudo tee -a /opt/local/etc/macports/pubkeys.conf >/dev/null
echo 'https://buildio.github.io/cli/macports/ports.tar' | sudo tee -a /opt/local/etc/macports/sources.conf >/dev/null
sudo port sync && sudo port install bld
```

### Windows (Chocolatey)

Install Chocolatey using elevated powershell:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iwr https://community.chocolatey.org/install.ps1 -UseBasicParsing | iex
```

```powershell
choco source add --name=buildio --source="https://buildio.github.io/cli/chocolatey/index.json"
choco install bld -y
```

### Windows (Scoop)

Install Scoop using non-elevated powershell:

```powershell
Set-ExecutionPolicy 4 0 -f;irm get.scoop.sh|iex;scoop install git
```

```powershell
scoop bucket add buildio https://github.com/buildio/cli
scoop install bld
```

### Linux (APT)

```bash
curl -fsSL https://buildio.github.io/cli/install.sh | sh
```

Same APT setup without `curl | sh`:

```bash
curl -fsSL https://buildio.github.io/cli/apt/gpg.key | gpg --batch --yes --dearmor | sudo tee /usr/share/keyrings/buildio-archive-keyring.gpg >/dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/buildio-archive-keyring.gpg] https://buildio.github.io/cli/apt stable main" | sudo tee /etc/apt/sources.list.d/buildio-cli.list >/dev/null
echo 'Dir::Etc{SourceList sources.list.d/buildio-cli.list;SourceParts /dev/null}#clear APT::Update;'|sudo apt-get -c/dev/fd/0 update --no-list-cleanup
sudo apt-get install -y buildio-archive-keyring bld
```

## Build

### Local Development Build
```bash
shards build
```

### Release Builds

The repository includes GitHub Actions that build release artifacts when a version tag is pushed. `.github/workflows/build-linux-binary.yml` builds the static Linux binary, Debian packages, and APT repository. `.github/workflows/build-macos-binary.yml` builds precompiled macOS binaries for MacPorts and publishes the MacPorts ports snapshot. The APT and MacPorts repositories are published to GitHub Pages. These actions:

- **Purpose**: Creates a completely static Linux binary using Alpine Linux for maximum portability
- **Use Cases**:
  - Provides an easy-to-use binary for Linux users without Crystal dependencies
  - Serves as a dependency for the [Build CLI CNB Buildpack](https://github.com/buildio/buildpack-bld-cli)
- **Trigger**: Automatically runs when pushing tags like `v1.1.6`
- **Build Process**: Uses Docker with Alpine Linux for the static Linux binary, and MacPorts-hosted dependencies on GitHub macOS runners for Darwin binaries that install under `/opt/local`; Intel binaries request `MACOSX_DEPLOYMENT_TARGET=10.7` for Lion and newer, while Apple Silicon binaries target macOS 11.0 and newer
- **Output**: Releases `bld-linux-amd64.zip`, `bld-darwin-amd64.tar.gz`, `bld-darwin-arm64.tar.gz`, `bld_<version>-1_amd64.deb`, and `buildio-archive-keyring_<version>-1_all.deb` package assets

To trigger a new release:

```bash
git tag v1.1.7
git push origin v1.1.7
```

APT publishing needs a stable GPG signing key because users' `apt` clients trust the repository through `/usr/share/keyrings/buildio-archive-keyring.gpg`. The workflow bootstraps that key automatically when `APT_GPG_PRIVATE_KEY_BASE64` is missing: it generates a repository signing key, uses it for the current publish, and saves `APT_GPG_PRIVATE_KEY_BASE64` through the persistent `APT_SECRET_BOOTSTRAP_TOKEN` secret. The signing key ID is derived from the imported private key on each run, so there is no separate key-id secret. The public key bundle is derived from the signing key by default; set the repository variable `APT_GPG_PUBLIC_KEYS_BASE64` only when planned rotation needs an old+new armored public-key bundle. Keeping `APT_SECRET_BOOTSTRAP_TOKEN` lets the workflow update APT signing secrets during future bootstrap/rotation work without another manual token handoff. To seed it, open GitHub's official fine-grained PAT form with prefilled owner/expiration/permission fields, select only the `buildio/cli` repository manually, generate the token, paste it into the prompt, and store it with `open 'https://github.com/settings/personal-access-tokens/new?name=Build.io+APT+bootstrap&description=Persistent+token+used+by+the+Build+CLI+release+workflow+to+store+and+rotate+APT+signing+secrets&target_name=buildio&expires_in=none&secrets=write' && read -rsp 'Paste fine-grained PAT: ' APT_SECRET_BOOTSTRAP_TOKEN && echo && gh secret set APT_SECRET_BOOTSTRAP_TOKEN --repo buildio/cli --body "$APT_SECRET_BOOTSTRAP_TOKEN"`. GitHub documents `target_name` as the resource owner, not as a selected repository, so the repository selection remains manual. The `buildio-archive-keyring` package owns `/usr/share/keyrings/buildio-archive-keyring.gpg`, so publish old+new public keys while the old key still signs the repository, let users update, then switch the private-key secret to the new signing key.

MacPorts publishing uses a Signify signature because `port sync` verifies HTTPS ports tree snapshots before extracting them. The macOS workflow bootstraps `MACPORTS_SIGNIFY_PRIVATE_KEY_BASE64` and `MACPORTS_SIGNIFY_PUBLIC_KEY_BASE64` through the same `APT_SECRET_BOOTSTRAP_TOKEN` secret when they are missing, publishes `macports/ports.tar`, signs it as `macports/ports.tar.sig`, and publishes `macports/buildio-ports.pub` for users to add to `pubkeys.conf`. The Portfile installs precompiled `bld-darwin-amd64.tar.gz` or `bld-darwin-arm64.tar.gz` release assets; it does not build the CLI from source on user machines. The Intel artifact requests the oldest 64-bit Intel deployment target, macOS 10.7 Lion, and the workflow fails if the produced binary reports a newer minimum target.

The workflow generates the published `install.sh` from the manual APT setup code block above, so that block is the single source of truth for both install paths.

If the workflow publishes `gh-pages` but `https://buildio.github.io/cli/install.sh` returns 404, enable GitHub Pages from the `gh-pages` branch root:

```bash
gh api --method POST repos/buildio/cli/pages -f source[branch]=gh-pages -f source[path]=/
```


## Using a Custom API URL

You can specify a custom API endpoint for the CLI by setting the `BUILD_API_URL` environment variable. This is useful for development or testing against a local or alternative Build API instance.

The URL should include the scheme (http or https) and the port if necessary.

**Example:**

To run the CLI against a local server running on `http://localhost:3000`:

```bash
BUILD_API_URL='http://localhost:3000' bld login
```

When `BUILD_API_URL` is set, the CLI will direct all API requests to this URL, and it will store a separate entry in your `.netrc` file for this custom host, ensuring your regular Build credentials are not overwritten.

If `BUILD_API_URL` is not set, the CLI defaults to `https://app.build.io`.

## Language selection

`bld` uses `BUILD_LOCALE` when set, then falls back to `LC_ALL`, `LC_MESSAGES`, and `LANG`. Supported values currently normalize to `en` or `ja`; unsupported locales, `C`, and `POSIX` fall back to English.

```bash
BUILD_LOCALE=ja bld help apps:list
```

## Contributors

- [Matthew Chigira](https://github.com/matthewchigira) - creator and maintainer

## License

All rights reserved.
