$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = 'bld'
  unzipLocation  = $toolsDir
  url64bit       = 'https://github.com/buildio/cli/releases/download/v1.1.130/bld-windows-amd64.zip'
  checksum64     = 'a57139e7ef44d0d35dc5c65f9d460e8fc5f92d599d5f4948886eab85bbd8912c'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
