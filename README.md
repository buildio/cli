# Build CLI

## Build

### Local Development Build
```bash
shards build
```

### Static Linux Binary Build

The repository includes a GitHub Action (`.github/workflows/build-linux-binary.yml`) that automatically builds a static Linux binary when a version tag is pushed. This action:

- **Purpose**: Creates a completely static Linux binary using Alpine Linux for maximum portability
- **Use Cases**:
  - Provides an easy-to-use binary for Linux users without Crystal dependencies
  - Serves as a dependency for the Build CLI Heroku buildpack
- **Trigger**: Automatically runs when pushing tags like `v1.1.6`
- **Build Process**: Uses Docker with Alpine Linux base image to create a fully static binary with all dependencies compiled in
- **Output**: Releases a `bld-linux-amd64.zip` file containing the static binary

To trigger a new release:
```bash
git tag v1.1.7
git push origin v1.1.7
```

The action will create a GitHub release with the Linux binary attached, which can be downloaded and used on any Linux AMD64 system without requiring any runtime dependencies.

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

## Contributors

- [Jonathan Siegel](https://github.com/usiegj00) - creator and maintainer

## License

All rights reserved.
