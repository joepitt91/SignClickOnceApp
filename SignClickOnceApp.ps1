<#
.SYNOPSIS 
    A PowerShell Script to correctly sign a ClickOnce Application.
.DESCRIPTION 
    Microsoft ClickOnce Applications Signed with a SHA256 Certificate show as Unknown Publisher during installation, ClickOnce Applications signed with a SHA1 Certificate show an Unknown Publisher SmartScreen Warning once installed, this happens because:
    1) The ClickOnce installer only supports SHA1 certificates (not SHA256), but,
    2) Microsoft has depreciated SHA1 for Authenticode Signing.
    
    This script uses two code signing certificates (one SHA1 and one SHA256) to sign the various parts of the ClickOnce Application so that both the ClickOnce Installer and SmartScreen are happy.
.PARAMETER VSRoot
    The Visual Studio Projects folder, if not provided .\Documents\Visual Studio 2015\Projects will be assumed
.PARAMETER SolutionName
    The Name of the Visual Studio Solution (Folder), if not provided the user is prompted.
.PARAMETER ProjectName
    The Name of the Visual Studio Project (Folder), if not provided the user is prompted.
.PARAMETER SHA1CertThumbprint
    The Thumbprint of the SHA1 Code Signing Certificate, if not provided the user is prompted.
.PARAMETER SHA256CertThumbprint
    The Thumbprint of the SHA256 Code Signing Certificate, if not provided the user is prompted.
.PARAMETER TimeStampingServer
    The Time Stamping Server to be used while signing, if not provided the user is prompted.
.PARAMETER PublisherName
    The Publisher to be set on the ClickOnce files, if not provided the user is prompted.
.PARAMETER Verbose
    Writes verbose output.
.EXAMPLE
    SignClickOnceApp.ps1 -VSRoot "C:\Users\Username\Documents\Visual Studio 2015\Projects" -SolutionName "MySolution" -ProjectName "MyProject" -SHA1CertThumbprint "f3f33ccc36ffffe5baba632d76e73177206143eb" -SHA256CertThumbprint "5d81f6a4e1fb468a3b97aeb3601a467cdd5e3266" -TimeStampingServer "http://time.certum.pl/" -PublisherName "Awesome Software Inc."
    Signs MyProject in MySolution which is in C:\Users\Username\Documents\Visual Studio 2015\Projects using the specified certificates, with a publisher of "Awesome Software Inc." and the Certum Timestamping Server.
.NOTES 
    Author  : Joe Pitt
    License : SignClickOnceApp by Joe Pitt is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
.LINK 
    https://www.joepitt.co.uk/Project/SignClickOnceApp/
#>
param (
    [string]$VSRoot, 
    [string]$SolutionName, 
    [string]$ProjectName, 
    [string]$SHA1CertThumbprint, 
    [string]$SHA256CertThumbprint, 
    [string]$TimeStampingServer,
    [string]$PublisherName,
    [switch]$Verbose
)

$oldverbose = $VerbosePreference
if($Verbose) 
{
	$VerbosePreference = "continue" 
}

# Visual Studio Root Path
if(!$PSBoundParameters.ContainsKey('VSRoot'))
{
    $VSRoot = '.\Documents\Visual Studio 2015\Projects\'
}
if (Test-Path "$VSRoot")
{
    Write-Verbose "Using '$VSRoot' for Visual Studio Root"
}
else
{
    Write-Error -Message "VSRoot does not exist." -RecommendedAction "Check path and try again" -ErrorId "1" `
        -Category ObjectNotFound -CategoryActivity "Testing VSRoot Path" -CategoryReason "The VSRoot path was not found" `
        -CategoryTargetName "$VSRoot" -CategoryTargetType "Directory"
    exit 1
}

# Solution Path
if(!$PSBoundParameters.ContainsKey('SolutionName'))
{
    $SolutionName = Read-Host "Solution Name"
}
if (Test-Path "$VSRoot\$SolutionName")
{
    Write-Verbose "Using '$VSRoot\$SolutionName' for Solution Path"
    $SolutionPath = "$VSRoot\$SolutionName"
}
else
{
    Write-Error -Message "Solution does not exist." -RecommendedAction "Check Solution Name and try again" -ErrorId "2" `
        -Category ObjectNotFound -CategoryActivity "Testing Solution Path" -CategoryReason "The Solution path was not found" `
        -CategoryTargetName "$VSRoot\$SolutionName" -CategoryTargetType "Directory"
    exit 2
}

# Project Path
if(!$PSBoundParameters.ContainsKey('ProjectName'))
{
    $ProjectName = Read-Host "Project Name"
}
if (Test-Path "$SolutionPath\$ProjectName")
{
    Write-Verbose "Using '$SolutionPath\$ProjectName' for Project Path"
    $ProjectPath = "$SolutionPath\$ProjectName"
}
else
{
    Write-Error -Message "Project does not exist." -RecommendedAction "Check Project Name and try again" -ErrorId "3" `
        -Category ObjectNotFound -CategoryActivity "Testing Project Path" -CategoryReason "The Project path was not found" `
        -CategoryTargetName "$SolutionPath\$ProjectName" -CategoryTargetType "Directory"
    exit 3
}

# Publish Path
if (Test-Path "$ProjectPath\publish")
{
    Write-Verbose "Using '$ProjectPath\publish' for Publish Path"
    $PublishPath = "$ProjectPath\publish"
}
else
{
    Write-Error -Message "Publish path does not exist." -RecommendedAction "Check Project has been published to \publish and try again" -ErrorId "4" `
        -Category ObjectNotFound -CategoryActivity "Testing Publish Path" -CategoryReason "The publish path was not found" `
        -CategoryTargetName "$ProjectPath\publish" -CategoryTargetType "Directory"
    exit 4
}

# Application Files Path
if (Test-Path "$PublishPath\Application Files")
{
    Write-Verbose "Using '$PublishPath\Application Files' for Application Files Path"
    $AppFilesPath = "$PublishPath\Application Files"
}
else
{
    Write-Error -Message "Application Files path does not exist." -RecommendedAction "Check Project has been published to \publish and try again" -ErrorId "5" `
        -Category ObjectNotFound -CategoryActivity "Testing Application Files Path" -CategoryReason "The Application Files path was not found" `
        -CategoryTargetName "$PublishPath\Application Files" -CategoryTargetType "Directory"
    exit 5
}

# Target Path
$TargetPath = Convert-Path "$AppFilesPath\${ProjectName}_*"
if ($($TargetPath.Length) -ne 0)
{
    Write-Verbose "Using $TargetPath for Target Path"
}
else
{
    Write-Error -Message "No versions." -RecommendedAction "Check Project has been published to \publish and try again" -ErrorId "6" `
        -Category ObjectNotFound -CategoryActivity "Searching for published version path" -CategoryReason "No Application has been published using ClickOnce" `
        -CategoryTargetName "$AppFilesPath\${ProjectName}_*" -CategoryTargetType "Directory"
    exit 6
}

# SHA1 Certificate
if(!$PSBoundParameters.ContainsKey('SHA1CertThumbprint'))
{
    $SHA1CertThumbprint = Read-Host "SHA1 Certificate Thumbprint"
}
if ("$SHA1CertThumbprint" -notmatch "^[0-9A-Fa-f]{40}$")
{
    Write-Error -Message "SHA1 Thumbprint Malformed" -RecommendedAction "Check the thumbprint and try again" -ErrorId "7" `
        -Category InvalidArgument -CategoryActivity "Verifying Thumbprint Format" -CategoryReason "Thumbprint is not a 40 character Base64 string" `
        -CategoryTargetName "$SHA1CertThumbprint" -CategoryTargetType "Base64String"
    exit 7
}
$SHA1Found = Get-ChildItem -Path Cert:\CurrentUser\My | where {$_.Thumbprint -eq "$SHA1CertThumbprint"} | Measure-Object
if ($SHA1Found.Count -eq 0)
{
    Write-Error -Message "SHA1 Certificate Not Found" -RecommendedAction "Check the thumbprint and try again" -ErrorId "8" `
        -Category ObjectNotFound -CategoryActivity "Searching for certificate" -CategoryReason "Certificate with Thumbprint not found" `
        -CategoryTargetName "$SHA1CertThumbprint" -CategoryTargetType "Base64String"
    exit 8
}

# SHA256 Certificate
if(!$PSBoundParameters.ContainsKey('SHA256CertThumbprint'))
{
    $SHA256CertThumbprint = Read-Host "SHA256 Certificate Thumbprint"
}
if ("$SHA256CertThumbprint" -notmatch "^[0-9A-Fa-f]{40}$")
{
    Write-Error -Message "SHA256 Thumbprint Malformed" -RecommendedAction "Check the thumbprint and try again" -ErrorId "9" `
        -Category InvalidArgument -CategoryActivity "Verifying Thumbprint Format" -CategoryReason "Thumbprint is not a 40 character Base64 string" `
        -CategoryTargetName "$SHA256CertThumbprint" -CategoryTargetType "Base64String"
    exit 9
}
$SHA256Found = Get-ChildItem -Path Cert:\CurrentUser\My | where {$_.Thumbprint -eq "$SHA256CertThumbprint"} | Measure-Object
if ($SHA256Found.Count -eq 0)
{
    Write-Error -Message "SHA256 Certificate Not Found" -RecommendedAction "Check the thumbprint and try again" -ErrorId "10" `
        -Category ObjectNotFound -CategoryActivity "Searching for certificate" -CategoryReason "Certificate with Thumbprint not found" `
        -CategoryTargetName "$SHA256CertThumbprint" -CategoryTargetType "Base64String"
    exit 10
}

# TimeStamping Server
if(!$PSBoundParameters.ContainsKey('TimeStampingServer'))
{
    $TimeStampingServer = Read-Host "TimeStamping Server URL"
}
if ("$TimeStampingServer" -notmatch "^http(s)?:\/\/[A-Za-z0-9-._~:/?#[\]@!$&'()*+,;=]+$")
{
    Write-Error -Message "SHA256 Thumbprint Malformed" -RecommendedAction "Check the TimeStamp URL and try again" -ErrorId "11" `
        -Category InvalidArgument -CategoryActivity "Verifying TimeStamping URL" -CategoryReason "TimeStamping URL is not a RFC Compliant URL" `
        -CategoryTargetName "$TimeStampingServer" -CategoryTargetType "URL"
    exit 11
}

# Publisher Name
# Project Path
if(!$PSBoundParameters.ContainsKey('PublisherName'))
{
    $PublisherName = Read-Host "Publisher Name"
}

# Sign setup.exe and application.exe with SHA256 Cert
Write-Verbose "Signing '$PublishPath\Setup.exe' (SHA256)"
Start-Process "$PSScriptRoot\signtool.exe" -ArgumentList "sign /fd SHA256 /td SHA256 /tr $TimeStampingServer /sha1 $SHA256CertThumbprint `"$PublishPath\Setup.exe`"" -Wait -NoNewWindow
Write-Verbose "Signing '$TargetPath\$ProjectName.exe.deploy' (SHA256)"
Start-Process "$PSScriptRoot\signtool.exe" -ArgumentList "sign /fd SHA256 /td SHA256 /tr $TimeStampingServer /sha1 $SHA256CertThumbprint `"$TargetPath\$ProjectName.exe.deploy`"" -Wait -NoNewWindow

# Remove .deploy extensions
Write-Verbose "Removing .deploy extensions"
Get-ChildItem "$TargetPath\*.deploy" -Recurse | Rename-Item -NewName { $_.Name -replace '\.deploy','' } 

# Sign Manifest with SHA256 Cert
Write-Verbose "Signing '$TargetPath\$ProjectName.exe.manifest' (SHA256)"
Start-Process "$PSScriptRoot\mage.exe" -ArgumentList "-update `"$TargetPath\$ProjectName.exe.manifest`" -ch $SHA256CertThumbprint -if `"Logo.ico`" -ti `"$TimeStampingServer`"" -Wait -NoNewWindow

# Sign ClickOnces with SHA1 Cert
Write-Verbose "Signing '$TargetPath\$ProjectName.application' (SHA1)"
Start-Process "$PSScriptRoot\mage.exe" -ArgumentList "-update `"$TargetPath\$ProjectName.application`"  -ch $SHA1CertThumbprint -appManifest `"$TargetPath\$ProjectName.exe.manifest`" -pub `"$PublisherName`" -ti `"$TimeStampingServer`"" -Wait -NoNewWindow
Write-Verbose "Signing '$PublishPath\$ProjectName.application' (SHA1)"
Start-Process "$PSScriptRoot\mage.exe" -ArgumentList "-update `"$PublishPath\$ProjectName.application`" -ch $SHA1CertThumbprint -appManifest `"$TargetPath\$ProjectName.exe.manifest`" -pub `"$PublisherName`" -ti `"$TimeStampingServer`"" -Wait -NoNewWindow

# Readd .deply extensions
Write-Verbose "Re-adding .deploy extensions"
Get-ChildItem -Path "$TargetPath\*"  -Recurse | Where-Object {!$_.PSIsContainer -and $_.Name -notlike "*.manifest" -and $_.Name -notlike "*.application"} | Rename-Item -NewName {$_.Name + ".deploy"}

###
exit 99

Invoke-Expression 'SignTool.exe sign /fd SHA256 /td SHA256 /tr http://time.certum.pl/ /sha1 5d81f6a4e1fb468a3b97aeb3601a467cdd5e3266 "$PublishDir\Setup.exe"'
Invoke-Expression 'SignTool.exe sign /fd SHA256 /td SHA256 /tr http://time.certum.pl/ /sha1 5d81f6a4e1fb468a3b97aeb3601a467cdd5e3266 "$AppDataDir\$SolutionName.exe.deploy"'
Get-ChildItem "$AppDataDir\*.deploy" -Recurse | Rename-Item -NewName { $_.Name -replace '\.deploy','' } 
Start-Process "C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.6.1 Tools\mage.exe" -ArgumentList "-update `"$AppDataDir\$SolutionName.exe.manifest`" -ch f3f33ccc36ffffe5baba632d76e73177206143eb -if `"Logo.ico`" -ti `"http://time.certum.pl/`"" -Wait -NoNewWindow
Start-Process "C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.6.1 Tools\mage.exe" -ArgumentList "-update `"$AppDataDir\$SolutionName.application`" -ch f3f33ccc36ffffe5baba632d76e73177206143eb -appManifest `"$AppDataDir\$SolutionName.exe.manifest`" -pub `"Joe Pitt`" -ti `"http://time.certum.pl/`"" -Wait -NoNewWindow
Start-Process "C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.6.1 Tools\mage.exe" -ArgumentList "-update `"$PublishDir\$SolutionName.application`" -ch f3f33ccc36ffffe5baba632d76e73177206143eb -appManifest `"$AppDataDir\$SolutionName.exe.manifest`" -pub `"Joe Pitt`" -ti `"http://time.certum.pl/`"" -Wait -NoNewWindow
Get-ChildItem -Path "$AppDataDir\*"  -Recurse | Where-Object {!$_.PSIsContainer -and $_.Name -notlike "*.manifest" -and $_.Name -notlike "*.application"} | Rename-Item -NewName {$_.Name + ".deploy"}