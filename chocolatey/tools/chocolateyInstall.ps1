$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.135/bld-windows-amd64.zip'
  checksum64     = 'ff06bddc1e8e79810507afd56f8f56155ef8e75d3051ca6608d04ce75ed41c3c'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
