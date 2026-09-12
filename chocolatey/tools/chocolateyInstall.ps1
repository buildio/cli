$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.108/bld-windows-amd64.zip'
  checksum64     = '17529eb00ef87f26fa4983dc1f5c890a00b46fdf3159ab385695d76c48d90f1e'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
