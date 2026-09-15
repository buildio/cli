$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.122/bld-windows-amd64.zip'
  checksum64     = '5db8edb7e8a24181bc59f8f1346e40958d1c625a6fb5f65700bfe9475405a49f'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
