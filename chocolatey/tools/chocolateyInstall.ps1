$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.2.3/bld-windows-amd64.zip'
  checksum64     = 'some-sha256'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
