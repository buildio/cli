$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.124/bld-windows-amd64.zip'
  checksum64     = 'a5dc4a7686318625b0f3baaf116496cdcdaf9bf47c3070e294c732ac7d8dd9cc'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
