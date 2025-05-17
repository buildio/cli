# Build CLI

## Build

```bash
shards build
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

## Contributors

- [Jonathan Siegel](https://github.com/usiegj00) - creator and maintainer

## License

All rights reserved.
