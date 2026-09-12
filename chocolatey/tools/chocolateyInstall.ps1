$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.107/bld-windows-amd64.zip'
  checksum64     = '4145169605fdaaf44161a6a4a433be7687bffe32c4a095fc1e5116a1da486df2'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
