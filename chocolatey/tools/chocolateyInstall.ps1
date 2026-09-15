$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.119/bld-windows-amd64.zip'
  checksum64     = 'b433dce1f942979bac52005179c6a55860f23bdbe800b16dabee0cb03a4931fd'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
