$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.116/bld-windows-amd64.zip'
  checksum64     = '33b392712b0d29ab7e2a2527a9b80ce60a325ab10e9279e40bb289713a47d01c'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
