$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.115/bld-windows-amd64.zip'
  checksum64     = '259785abd94c3248d13781f0ab0fd12648cfe0fef6a2788ad762512374bede36'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
