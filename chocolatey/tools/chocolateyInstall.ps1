$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.125/bld-windows-amd64.zip'
  checksum64     = '0dcd529781fabcb3aa594462177462d092e29f257191e0df302319cb1735af1d'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
