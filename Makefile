# Define variables
PLATFORM ?= linux/amd64
BINARY := bld
BINDIR := bin/linux-$(notdir $(PLATFORM))/
REPO := buildio/bins
ZIPFILE := bld-linux-$(notdir $(PLATFORM)).zip

# Define the default target
.PHONY: build release clean
build:
	# Build CLI ends up in $(BINDIR)$(BINARY)
	mkdir -p $(BINDIR)
	docker build -t bld-cli-build .
	docker run --rm --platform $(PLATFORM) -v "$(PWD):/workspace" bld-cli-build \
	sh -c "shards check || shards install --production --frozen && crystal build src/build_cli.cr --release --no-debug --static -o $(BINDIR)$(BINARY) && strip $(BINDIR)$(BINARY);"

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

