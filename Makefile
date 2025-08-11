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

# Create a release and upload the zipped binary
release: #build
	@if [ -z "$(VERSION)" ]; then \
	    echo "Error: VERSION is not set. Use 'make release VERSION=x.y.z' to specify the version."; \
	    exit 1; \
	fi
	@echo "Releasing version $(VERSION)..."
	@if [ ! -f "$(BINDIR)$(BINARY)" ]; then echo "Binary file $(BINDIR)$(BINARY) does not exist."; false; fi
	cd $(BINDIR) && zip -j $(ZIPFILE) $(BINARY)
	@if [ ! -f "$(BINDIR)$(ZIPFILE)" ]; then echo "Failed to create zip file $(BINDIR)$(ZIPFILE)."; false; fi
	gh release create v$(VERSION) $(BINDIR)$(ZIPFILE) --repo $(REPO) --title "Release v$(VERSION)" --notes "Release of version $(VERSION)";
	@$(MAKE) clean

# Clean up the zipped file
clean:
	@echo "Cleaning up..."
	rm -f $(ZIPFILE)
