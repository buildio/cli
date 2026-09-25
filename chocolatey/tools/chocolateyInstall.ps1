$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.133/bld-windows-amd64.zip'
  checksum64     = '5b83f29c97676e2345f27649aa2dfba3a34a037647205ef98fd069fb922e4bb2'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
