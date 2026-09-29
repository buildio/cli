$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.140/bld-windows-amd64.zip'
  checksum64     = '5f277c943632b010474622b9d43065682696b6523b6308bad3fad85f4cddd884'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
