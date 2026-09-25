$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.132/bld-windows-amd64.zip'
  checksum64     = 'd1cb1b2b8eee8be7b97e6a37cabe271d72a462d7251bba5bbb0b763afae4d519'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
