$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.113/bld-windows-amd64.zip'
  checksum64     = '29375b592e278d505e8d13bd86ecb0b743acd9fae6883f423024bdb5ca64b737'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
