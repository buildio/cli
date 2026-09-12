$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.114/bld-windows-amd64.zip'
  checksum64     = '99f1e274b3c66108fc366ea77987014b2cf2e86a641b7fac6285ce4aa36a92e4'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
