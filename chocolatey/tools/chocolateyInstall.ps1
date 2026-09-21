$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.127/bld-windows-amd64.zip'
  checksum64     = '5cb122e8dd9c603129c687b83640d5df7d54cc40a64ec541ca75574d2dbd2203'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
