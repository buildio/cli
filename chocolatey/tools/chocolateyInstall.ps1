$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.128/bld-windows-amd64.zip'
  checksum64     = '7a75be5ecda65c6302bca34c7851cb83c2acef0601058830c20bc0e08f3d1d13'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
