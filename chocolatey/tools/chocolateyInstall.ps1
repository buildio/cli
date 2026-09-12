$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.110/bld-windows-amd64.zip'
  checksum64     = '78c42ef62e9527ad59be6c7247301799896c2bcad5d67e575c8a979eea196e6b'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
