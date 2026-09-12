$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.112/bld-windows-amd64.zip'
  checksum64     = '156af875237f6c177e9698fdd1932f68c1716dd6600e142dd8d6c9c83eee2ab6'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
