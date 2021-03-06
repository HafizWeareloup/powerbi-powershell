##############################
#.SYNOPSIS
# Generates Windows file security catalogs (CAT) for PowerShell modules.
#
#.DESCRIPTION
# Creates Windows file security catalogs (CAT) for PowerShell modules by detecting unpacked NuGet packages containing *.nuspec files. 
#
#.EXAMPLE
# PS:> .\GenerateFileCatalog.ps1 -Path ..\PkgOut\Reset
# Generates Windows file security catalogs (CAT) for PkgOut\Reset directory
#
#.NOTES
# For more information on File Catalogs relating to PowerShell, see https://docs.microsoft.com/en-us/powershell/wmf/5.1/catalog-cmdlets.
##############################
[CmdletBinding()]
param
(
    # Parent directory containing *.nuspec files.
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Path,

    # File hash version for catalog file (default is 2): 1 for SHA1 (Windows 7 & Server 2008 R2), 2 for SHA2 newer versions of Windows.
    [int] $CatalogVersion = 2,

    # Staging\temporary directory (must already exist). Defaults to $env:Temp.
    [ValidateNotNullOrEmpty()]
    [string] $StagingDir = $env:Temp
)

Write-Output "Running $($MyInvocation.MyCommand.Name)"

if(!(Test-Path -Path $Path)) {
    throw "-Path not found: $Path"
}

$nuspecFiles = Get-ChildItem -Path $Path -Filter *.nuspec -Recurse
if(!$nuspecFiles) {
    throw "No *.nuspec files found under: $Path"
}

foreach($nuspecFile in $nuspecFiles) {
    # $moduleName = $nuspecFile.BaseName <- makes it be lowercase
    $nuspecContent = [xml](Get-Content -Path $nuspecFile.FullName -ErrorAction Stop -Raw)
    $moduleName = $nuspecContent.package.metadata.id
    $nuspecDirectory = $nuspecFile.Directory.FullName
    $nuspecFilePath = $nuspecFile.FullName
    
    Write-Output "Generating File Catalog (CAT) for module '$moduleName' in directory: $nuspecDirectory"
    $catalogFilePath = Join-Path -Path $nuspecDirectory -ChildPath "$moduleName.cat"
    
    # Move the Nuspec out temporary to get correct checksum
    $nuspecTemp = Join-Path -Path $StagingDir -ChildPath $nuspecFile.Name
    Move-Item -Path $nuspecFilePath -Destination $nuspecTemp -Force
    
    $newFileCatalogParams = @{
        Path = $nuspecDirectory
        CatalogFilePath = $catalogFilePath
        CatalogVersion = $CatalogVersion
        Verbose = $VerbosePreference
    }

    [void](Microsoft.PowerShell.Security\New-FileCatalog @newFileCatalogParams)

    # Move nuspec back
    Move-Item -Path $nuspecTemp -Destination $nuspecFilePath -Force

    if(!(Test-Path -Path $catalogFilePath)) {
        throw "Failed to generate CAT file: $catalogFilePath"
    }
}

Write-Output "Completed running $($MyInvocation.MyCommand.Name)"