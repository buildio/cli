# Build CLI

## Install (Operating Systems (Package Manager))
### macOS 15+ / Linux (Homebrew)

Install Homebrew and setup envs:

```sh
brew -v||eval "$(bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"|tee /dev/fd/2|grep '^    [es]')"
```

```sh
brew install buildio/cli/bld;brew trust buildio/cli
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

### Static Linux Binary Build

The repository includes a GitHub Action (`.github/workflows/build-linux-binary.yml`) that automatically builds a static Linux binary and Debian package when a version tag is pushed. The APT repository is published to GitHub Pages. This action:

- **Purpose**: Creates a completely static Linux binary using Alpine Linux for maximum portability
- **Use Cases**:
  - Provides an easy-to-use binary for Linux users without Crystal dependencies
  - Serves as a dependency for the [Build CLI CNB Buildpack](https://github.com/buildio/buildpack-bld-cli)
- **Trigger**: Automatically runs when pushing tags like `v1.1.6`
- **Build Process**: Uses Docker with Alpine Linux base image to create a fully static binary with all dependencies compiled in
- **Output**: Releases a `bld-linux-amd64.zip` file containing the static binary, plus `bld_<version>-1_amd64.deb` and `buildio-archive-keyring_<version>-1_all.deb` package assets

To trigger a new release:

```bash
git tag v1.1.7
git push origin v1.1.7
```

APT publishing needs a stable GPG signing key because users' `apt` clients trust the repository through `/usr/share/keyrings/buildio-archive-keyring.gpg`. The workflow bootstraps that key automatically when `APT_GPG_PRIVATE_KEY_BASE64` is missing: it generates a repository signing key, uses it for the current publish, and saves `APT_GPG_PRIVATE_KEY_BASE64` through the persistent `APT_SECRET_BOOTSTRAP_TOKEN` secret. The signing key ID is derived from the imported private key on each run, so there is no separate key-id secret. The public key bundle is derived from the signing key by default; set the repository variable `APT_GPG_PUBLIC_KEYS_BASE64` only when planned rotation needs an old+new armored public-key bundle. Keeping `APT_SECRET_BOOTSTRAP_TOKEN` lets the workflow update APT signing secrets during future bootstrap/rotation work without another manual token handoff. To seed it, open GitHub's official fine-grained PAT form with prefilled owner/expiration/permission fields, select only the `buildio/cli` repository manually, generate the token, paste it into the prompt, and store it with `open 'https://github.com/settings/personal-access-tokens/new?name=Build.io+APT+bootstrap&description=Persistent+token+used+by+the+Build+CLI+release+workflow+to+store+and+rotate+APT+signing+secrets&target_name=buildio&expires_in=none&secrets=write' && read -rsp 'Paste fine-grained PAT: ' APT_SECRET_BOOTSTRAP_TOKEN && echo && gh secret set APT_SECRET_BOOTSTRAP_TOKEN --repo buildio/cli --body "$APT_SECRET_BOOTSTRAP_TOKEN"`. GitHub documents `target_name` as the resource owner, not as a selected repository, so the repository selection remains manual. The `buildio-archive-keyring` package owns `/usr/share/keyrings/buildio-archive-keyring.gpg`, so publish old+new public keys while the old key still signs the repository, let users update, then switch the private-key secret to the new signing key.

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
