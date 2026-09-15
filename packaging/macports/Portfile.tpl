# -*- tcl -*-
PortSystem          1.0

name                bld
version             @VERSION@
revision            0
categories          sysutils net
platforms           darwin
supported_archs     x86_64 arm64
universal_variant   no
license             MIT
maintainers         {build.io:support @buildio} openmaintainer

description         Build.io command-line client
long_description    Heroku-compatible command-line client for Build.io.
homepage            https://app.build.io

master_sites        https://github.com/buildio/cli/releases/download/v${version}/

if {${build_arch} eq "arm64"} {
    distname        bld-darwin-arm64
    checksums       rmd160  @ARM64_RMD160@ \
                    sha256  @ARM64_SHA256@ \
                    size    @ARM64_SIZE@
} elseif {${build_arch} eq "x86_64"} {
    distname        bld-darwin-amd64
    checksums       rmd160  @X86_64_RMD160@ \
                    sha256  @X86_64_SHA256@ \
                    size    @X86_64_SIZE@
} else {
    known_fail      yes
    pre-fetch {
        return -code error "bld provides prebuilt MacPorts binaries for x86_64 and arm64 only"
    }
}

depends_lib         port:boehmgc \
                    port:libevent \
                    port:libiconv \
                    port:libssh2 \
                    port:libxml2 \
                    port:libyaml \
                    path:lib/libssl.dylib:openssl3 \
                    port:pcre2

use_configure       no
build {}

destroot {
    xinstall -d ${destroot}${prefix}/bin
    xinstall -m 0755 ${worksrcpath}/bld ${destroot}${prefix}/bin/bld
}
