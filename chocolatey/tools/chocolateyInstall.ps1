$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.111/bld-windows-amd64.zip'
  checksum64     = 'ff43c8b6bec0aa7c94d7d9dd7c1778ac46dcf7124c152de6a86a997122df133f'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
