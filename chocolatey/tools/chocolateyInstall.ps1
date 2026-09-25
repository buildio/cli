$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.137/bld-windows-amd64.zip'
  checksum64     = '114d55a8743182b0aa4b3ea3382ebabc9f8e7e93f55fb93dcd7d72efaf8e0184'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
