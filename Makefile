# Define variables
BINARY := bin/bld
REPO := buildio/bins
ZIPFILE := bin/bld-linux-amd64.zip

# Define the default target
.PHONY: build release clean
build:
	docker build -t bld-cli-build .
	docker run -it --rm --platform linux/amd64 -v "$(PWD):/workspace" bld-cli-build \
	sh -c "shards build --release --production --no-debug --static; strip bin/bld;"

# Create a release and upload the zipped binary
release: build
	@if [ -z "$(VERSION)" ]; then \
	    echo "Error: VERSION is not set. Use 'make release VERSION=x.y.z' to specify the version."; \
	    exit 1; \
	fi
	@echo "Releasing version $(VERSION)..."
	@if [ ! -f "$(BINARY)" ]; then echo "Binary file $(BINARY) does not exist."; false; fi
	zip -j $(ZIPFILE) $(BINARY)
	gh release create v$(VERSION) $(ZIPFILE) --repo $(REPO) --title "Release v$(VERSION)" --notes "Release of version $(VERSION)"
	@$(MAKE) clean

# Clean up the zipped file
clean:
	@echo "Cleaning up..."
	rm -f $(ZIPFILE)