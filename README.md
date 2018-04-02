# Sign ClickOnce App (SignClickOnceApp.ps1)
**A PowerShell Script to correctly sign a ClickOnce Application using a SHA256 Certificate.**

Microsoft ClickOnce Applications Signed with a SHA256 Certificate show as Unknown Publisher during installation, ClickOnce Applications signed with a SHA1 Certificate show an Unknown Publisher SmartScreen Warning once installed, this happens because:

1) The ClickOnce installer only supports SHA1 certificates (not SHA256) without a specific override when signing, but,
2) Microsoft has depreciated SHA1 for Authenticode Signing.
    
This script signs the various parts of the ClickOnce Application so that both the ClickOnce Installer and SmartScreen are happy.

## Links
* [Project Page](https://www.joepitt.co.uk/Project/SignClickOnceApp/)
* [Issues](https://github.com/joepitt91/SignClickOnceApp/issues)

## Usage
Extract the ZIP archive and open PowerShell, run  .\SignClickOnceApp.ps1, with the options below.

### Options
* **-VSRoot** The Visual Studio Projects folder, if not provided *.\Documents\Visual Studio 2015\Projects* will be assumed
* **-SolutionName** The Name of the Visual Studio Solution (Folder), if not provided the user is prompted.
* **-ProjectName** The Name of the Visual Studio Project (Folder), if not provided the user is prompted.
* **-SHA256CertThumbprint** The Thumbprint of the SHA256 Code Signing Certificate, if not provided the user is prompted.
* **-TimeStampingServer** The Time Stamping Server to be used while signing, if not provided the user is prompted.
* **-PublisherName** The Publisher to be set on the ClickOnce files, if not provided the user is prompted.
* **-Verbose** Writes verbose output.
