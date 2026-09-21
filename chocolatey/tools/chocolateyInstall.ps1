$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.126/bld-windows-amd64.zip'
  checksum64     = '6bc09d2a082364b245d9c445a1569f39e35eef85b9ae0905b9ebfd6c637cf1a3'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
