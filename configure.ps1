<#
.SYNOPSIS
    Configures CouchDB for building.
.DESCRIPTION
    This command is responsible for generating the build
    system for Apache CouchDB.

  -DisableFauxton            request build process skip building Fauxton (default false)
  -DisableDocs               request build process skip building documentation (default false)
  -SkipDeps                  do not update Erlang dependencies (default false)
  -CouchDBUser USER          set the username to run as (defaults to current user)
  -SpiderMonkeyVersion VSN   select the version of SpiderMonkey to use (default 91)

  Installation directories:
  -Prefix PREFIX             install architecture-independent files in PREFIX
                               [C:\Program Files\Apache\CouchDB]
  -ExecPrefix EPREFIX        install architecture-dependent files in EPREFIX
                               [same as PREFIX]

  Fine tuning of the installation directories:
  -BinDir DIR               user executables [EPREFIX\bin]
  -LibexecDir DIR           program executables [EPREFIX\libexec]
  -LibDir DIR               object code libraries [EPREFIX\lib]
  -SysconfDir DIR           read-only single-machine data [PREFIX\etc]
  -DataRootDir DIR          read-only arch.-independent data root [PREFIX\share]
  -LocalStateDir DIR        modifiable single-machine data [PREFIX\var]
  -RunStateDir DIR          modifiable single-machine runstate data [LOCALSTATEDIR\run]
  -DatabaseDir DIR          specify the data directory [LOCALSTATEDIR\lib]
  -ViewindexDir DIR         specify the view directory [LOCALSTATEDIR\lib]
  -LogDir DIR               specify the log directory [LOCALSTATEDIR\log]
  -DataDir DIR              read-only architecture-independent data [DATAROOTDIR]
  -ManDir DIR               man documentation [DATAROOTDIR\man]
  -DocDir DIR               documentation root [DATAROOTDIR\doc\apache-couchdb]
  -HTMLDir DIR              html documentation [DOCDIR\html]
.LINK
    http://couchdb.apache.org/
#>

#REQUIRES -Version 2.0
[cmdletbinding()]

Param(
    [switch]$Test = $false,
    [switch]$DisableFauxton = $false, # do not build Fauxton
    [switch]$DisableDocs = $false, # do not build any documentation or manpages
    [switch]$SkipDeps = $false, # do not update erlang dependencies

    [ValidateNotNullOrEmpty()]
    [string]$CouchDBUser = [Environment]::UserName, # set the username to run as (defaults to current user)
    [ValidateNotNullOrEmpty()]
    [string]$SpiderMonkeyVersion = "91", # select the version of SpiderMonkey to use (default 91)
    [ValidateNotNullOrEmpty()]
    [string]$Prefix = "C:\Program Files\Apache\CouchDB", # install architecture-independent file location (default C:\Program Files\Apache\CouchDB)
    [ValidateNotNullOrEmpty()]
    [string]$ExecPrefix = $Prefix, # install architecture-dependent file location (default C:\Program Files\Apache\CouchDB)
    [ValidateNotNullOrEmpty()]
    [string]$BinDir = "$ExecPrefix\bin", # user executable file location (default $ExecPrefix\bin)
    [ValidateNotNullOrEmpty()]
    [string]$LibExecDir = "$ExecPrefix\libexec", # user executable file location (default $ExecPrefix\libexec)
    [ValidateNotNullOrEmpty()]
    [string]$LibDir = "$ExecPrefix\lib", # object code libraries (default $ExecPrefix\lib)
    [ValidateNotNullOrEmpty()]

    [Alias("EtcDir")]
    [string]$SysConfDir = "$Prefix\etc", # read-only single-machine data (default $Prefix\etc)
    [ValidateNotNullOrEmpty()]
    [string]$DataRootDir = "$Prefix\share", # read-only arch.-independent data root (default $Prefix\share)

    [ValidateNotNullOrEmpty()]
    [string]$LocalStateDir = "$Prefix\var", # modifiable single-machine data (default $Prefix\var)
    [ValidateNotNullOrEmpty()]
    [string]$RunStateDir = "$LocalStateDir\run", # modifiable single-machine run state (default $LocalStateDir\run)
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseDir = "$LocalStateDir\lib", # database directory (default $LocalStateDir\lib)
    [ValidateNotNullOrEmpty()]
    [string]$ViewIndexDir = "$LocalStateDir\lib", # database view index directory (default $LocalStateDir\lib)
    [ValidateNotNullOrEmpty()]
    [string]$LogDir = "$LocalStateDir\log", # logging directory (default $LocalStateDir\log)

    [ValidateNotNullOrEmpty()]
    [string]$DataDir = "$DataRootDir", # read-only arch.-independent data (default $DataRootDir)
    [ValidateNotNullOrEmpty()]
    [string]$ManDir = "$DataRootDir\man", # man documentation (default $DataRootDir\man)
    [ValidateNotNullOrEmpty()]

    [string]$DocDir = "$DataRootDir\doc\apache-couchdb", # man documentation (default $DataRootDir\doc\apache-couchdb)
    [ValidateNotNullOrEmpty()]
    [string]$HTMLDir = "$DocDir\html" # html documentation (default $DocDir\html)
)


# determine this script’s directory and change to it
$rootdir = split-path -parent $MyInvocation.MyCommand.Definition
Push-Location $rootdir
[Environment]::CurrentDirectory = $PWD

# We use this for testing this script
# The test script lives in test/build/test-configure.sh
If ($Test) {
    Write-Output @"
"$Prefix" "$ExecPrefix" "$BinDir" "$LibExecDir" "$SysConfDir" "$DataRootDir" "$DataDir" "$LocalStateDir" "$RunStateDir" "$DocDir" "$LibDir" "$DatabaseDir" "$ViewIndexDir" "$LogDir" "$ManDir" "$HTMLDir"
"@
    exit 0
}

# Use the MSVC linker to determine if the respective SpiderMonkey library
# is available on the linker path.  This heuristic is taken from
# src/couch/rebar.config.script, please keep them in sync.
If ($SpiderMonkeyVersion -eq "1.8.5") {
    $SpiderMonkeyLib = "mozjs185-1.0.lib"
}
else {
    $SpiderMonkeyLib = "mozjs-$SpiderMonkeyVersion.lib"
}

&link $SpiderMonkeyLib /SUBSYSTEM:CONSOLE /NOENTRY /DLL /OUT:NUL *> $null
If ($LASTEXITCODE -ne 0) {
    Write-Output "ERROR: SpiderMonkey $SpiderMonkeyVersion is not found. Please specify with -SpiderMonkeyVersion."
    exit 1
}

# Translate ./configure variables to CouchDB variables
$PackageAuthorName="The Apache Software Foundation"
$InstallDir="$LibDir\couchdb"
$LogFile="$LogDir\couch.log"
$BuildFauxton = [int](-not $DisableFauxton)
$BuildDocs = [int](-not $DisableDocs)
$Hostname = [System.Net.Dns]::GetHostEntry([string]"localhost").HostName

Write-Verbose "==> configuring couchdb in rel\couchdb.config"
$CouchDBConfig = @"
% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License. You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
% License for the specific language governing permissions and limitations under
% the License.
%
% The contents of this file are auto-generated by configure
%
{package_author_name, "$PackageAuthorName"}.
{prefix, "."}.
{data_dir, "./data"}.
{view_index_dir, "./data"}.
{log_file, ""}.
{fauxton_root, "./share/www"}.
{user, "$CouchDBUser"}.
{spidermonkey_version, "$SpiderMonkeyVersion"}.
{node_name, "-name couchdb@localhost"}.
{cluster_port, 5984}.
{backend_port, 5986}.
{prometheus_port, 17986}.
"@
$CouchDBConfig | Out-File "$rootdir\rel\couchdb.config" -encoding ascii

#TODO: Output MS NMake file format? Stick with GNU Make?
$InstallMk = @"
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#
# The contents of this file are auto-generated by configure
#
package_author_name = $PackageAuthorName
install_dir = $InstallDir

bin_dir = $BinDir
libexec_dir = $LibExecDir\couchdb
doc_dir = $DocDir\couchdb
sysconf_dir = $SysConfDir\couchdb
data_dir = $DataDir\couchdb

database_dir = $DatabaseDir
view_index_dir = $ViewIndexDir
log_file = $LogFile

html_dir = $HTMLDir
man_dir = $ManDir

with_fauxton = $BuildFauxton
with_docs = $BuildDocs

user = $CouchDBUser
spidermonkey_version = $SpiderMonkeyVersion
"@
$InstallMk | Out-File "$rootdir\install.mk" -encoding ascii

$ConfigERL = @"
{spidermonkey_version, "$SpiderMonkeyVersion"}.
"@
$ConfigERL | Out-File "$rootdir\config.erl" -encoding ascii

if (((Get-Command "rebar.cmd" -ErrorAction SilentlyContinue) -eq $null) -or
    ((Get-Command "rebar3.cmd" -ErrorAction SilentlyContinue) -eq $null) -or
    ((Get-Command "erlfmt.cmd" -ErrorAction SilentlyContinue) -eq $null)) {
  $env:Path += ";$rootdir\bin"
}

# check for rebar; if not found, build it and add it to our path
if ((Get-Command "rebar.cmd" -ErrorAction SilentlyContinue) -eq $null)
{
   Write-Verbose "==> rebar.cmd not found; bootstrapping..."
   if (-Not (Test-Path "src\rebar"))
   {
      git clone --depth 1 https://github.com/apache/couchdb-rebar.git $rootdir\src\rebar
   }
   cmd /c "cd src\rebar && $rootdir\src\rebar\bootstrap.bat"
   cp $rootdir\src\rebar\rebar $rootdir\bin\rebar
   cp $rootdir\src\rebar\rebar.cmd $rootdir\bin\rebar.cmd
   make -C $rootdir\src\rebar clean
}

# check for rebar3; if not found, build it and add it to our path
if ((Get-Command "rebar3.cmd" -ErrorAction SilentlyContinue) -eq $null)
{
   Write-Verbose "==> rebar3.cmd not found; bootstrapping..."
   if (-Not (Test-Path "src\rebar3"))
   {
      git clone --depth 1 https://github.com/erlang/rebar3.git $rootdir\src\rebar3
   }
   cd src\rebar3
   .\bootstrap.ps1
   cp $rootdir\src\rebar3\rebar3 $rootdir\bin\rebar3
   cp $rootdir\src\rebar3\rebar3.cmd $rootdir\bin\rebar3.cmd
   cp $rootdir\src\rebar3\rebar3.ps1 $rootdir\bin\rebar3.ps1
   make -C $rootdir\src\rebar3 clean
   cd ..\..
}

# check for erlfmt; if not found, build it and add it to our path
if ((Get-Command "erlfmt.cmd" -ErrorAction SilentlyContinue) -eq $null)
{
   Write-Verbose "==> erlfmt.cmd not found; bootstrapping..."
   if (-Not (Test-Path "src\erlfmt"))
   {
      git clone --depth 1 https://github.com/WhatsApp/erlfmt.git $rootdir\src\erlfmt
   }
   cd src\erlfmt
   rebar3 as release escriptize
   cp $rootdir\src\erlfmt\_build\release\bin\erlfmt $rootdir\bin\erlfmt
   cp $rootdir\src\erlfmt\_build\release\bin\erlfmt.cmd $rootdir\bin\erlfmt.cmd
   make -C $rootdir\src\erlfmt clean
   cd ..\..
}

# only update dependencies, when we are not in a release tarball
if ( (Test-Path .git -PathType Container) -and (-not $SkipDeps) ) {
    Write-Verbose "==> updating dependencies"
    rebar get-deps update-deps
}

Pop-Location
[Environment]::CurrentDirectory = $PWD
Write-Output "You have configured Apache CouchDB, time to relax. Relax."
