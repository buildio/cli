$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.134/bld-windows-amd64.zip'
  checksum64     = '70a4fed101e42512377e9c398545c926c4d23259194fd8fe0a4a4da131a53211'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
