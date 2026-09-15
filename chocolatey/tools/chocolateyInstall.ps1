$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.121/bld-windows-amd64.zip'
  checksum64     = 'e7c5a9a13a8e89d92f58f6935c674204175be49d2a56fcefb80e58367dc2a0ab'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
