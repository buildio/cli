$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.131/bld-windows-amd64.zip'
  checksum64     = 'be75991712fc461b6095a610480c10c0f01ba9e7c21caf5eb3e9383abeeef6e5'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
