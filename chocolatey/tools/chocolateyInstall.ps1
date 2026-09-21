$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.123/bld-windows-amd64.zip'
  checksum64     = '865c5433ad8c48c1546e97d6eb40257248abe9a431b33c05915f4179e15fdabb'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
