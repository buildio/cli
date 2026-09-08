# Build CLI

## Install
### macOS (Homebrew)

```zsh
brew install buildio/cli/bld;brew trust buildio/cli
```

### Windows (Scoop)

```powershell
scoop bucket add buildio https://github.com/buildio/cli
scoop install bld
```

### Linux (APT)

```bash
curl -fsSL https://buildio.github.io/cli/install.sh | sh
```

If you previously installed `bld` manually into `/usr/local/bin`, remove that copy or ensure `/usr/bin` appears first in `PATH`; otherwise the manual binary can shadow the APT package.

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

APT publishing requires GitHub Pages to serve the `gh-pages` branch and these repository secrets: `APT_GPG_PRIVATE_KEY_BASE64`, `APT_GPG_PASSPHRASE`, and `APT_GPG_KEY_ID`. `APT_GPG_PUBLIC_KEYS_BASE64` can optionally provide an armored public-key bundle for planned rotations. The `buildio-archive-keyring` package owns `/usr/share/keyrings/buildio-archive-keyring.gpg`, so publish old+new public keys while the old key still signs the repository, let users update, then switch `APT_GPG_KEY_ID` and the private-key secret to the new signing key.

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
