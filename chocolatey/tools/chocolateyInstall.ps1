$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.136/bld-windows-amd64.zip'
  checksum64     = '97f62667d48ea7fb9854e339875b2c7c8eb9153bc8f5fcc0efc1a6cbdd7719c1'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
