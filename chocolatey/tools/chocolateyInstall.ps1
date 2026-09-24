$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.129/bld-windows-amd64.zip'
  checksum64     = 'f8b15bfd3f5d9bac33f085addde401f151c4761ac6790e35378031513ad68dbf'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
