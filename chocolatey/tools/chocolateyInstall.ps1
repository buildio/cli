$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.120/bld-windows-amd64.zip'
  checksum64     = 'a89250caeb83bf60eff647367de1cf30340b56cf0c2fd2617003d1ff829e9777'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
