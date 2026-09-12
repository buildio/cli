$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.109/bld-windows-amd64.zip'
  checksum64     = 'e0737482e7dd4ff53ea2c7636482883bce85ffb93380e9d3add44f171a0e4bf1'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
