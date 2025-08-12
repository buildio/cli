# Define variables
BINARY := bld
BINDIR := bin/linux-amd64/
REPO := buildio/bins
ZIPFILE := bld-linux-amd64.zip

# Define the default target
.PHONY: build release clean
build:
	# Build CLI ends up in bin/linux-amd64/bld
	mkdir -p $(BINDIR)
	docker build -t bld-cli-build .
	# sh -c "shards build --release --production --no-debug --static bld -o $(BINARY); strip $(BINARY);"
	docker run --rm --platform linux/amd64 -v "$(PWD):/workspace" bld-cli-build \
	sh -c "shards check || shards install --production --frozen && crystal build src/build_cli.cr --release --no-debug --static -o $(BINDIR)$(BINARY); strip $(BINDIR)$(BINARY);"

# Create a release zip (for local testing or CI)
release-zip: build
	@echo "Creating release zip..."
	@if [ ! -f "$(BINDIR)$(BINARY)" ]; then echo "Binary file $(BINDIR)$(BINARY) does not exist."; false; fi
	cd $(BINDIR) && zip -j $(ZIPFILE) $(BINARY)
	@if [ ! -f "$(BINDIR)$(ZIPFILE)" ]; then echo "Created zip file $(BINDIR)$(ZIPFILE)."; fi

# Legacy release target (now handled by GitHub Actions)
release:
	@echo "Note: Releases are now handled by GitHub Actions."
	@echo "Push a tag like 'v1.1.6' to trigger the release workflow."
	@echo "Or use 'make release-zip' to create the zip locally."

# Clean up the zipped file
clean:
	@echo "Cleaning up..."
	rm -f $(ZIPFILE)
