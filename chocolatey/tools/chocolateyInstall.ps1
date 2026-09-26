$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.139/bld-windows-amd64.zip'
  checksum64     = '03c9204f4ffe21a1772415eaca977d24c3089e531dcaba9a1716b43273439272'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
