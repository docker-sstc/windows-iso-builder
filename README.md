# windows-iso-builder

Scripts for customizing your own Windows ISO images.

## Prepare

- Download `oscdimg.exe` from microsoft
  - Download `adksetup.exe` from `https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install`
  - Execute `adksetup.exe` to install ADK (Choose `Development Tools` only)
  - The installation path should be `C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg`
  - Add `oscdimg.exe` to the PATH

- Download windows 11 iso file from `https://www.microsoft.com/software-download/windows11`
  - Choose `Download Windows 11 Disk Image (ISO) for x64 devices`

- Mount the iso file via `File Explorer`
- Get the image version: `dism /Get-WimInfo /WimFile:d:\sources\install.wim /index:6`

- Git clone this repo
- Open `Command Prompt` and execute `powershell -ExecutionPolicy Bypass -File <version>\build.ps1` to build
  - Or open `Powershell` and execute something like:

    ```powershell
    Set-ExecutionPolicy RemoteSigned
    .\<version>\build.ps1
    Set-ExecutionPolicy Restricted
    ```

## Refs

- `https://github.com/ntdevlabs/tiny11builder`
- `https://schneegans.de/windows/unattend-generator/`
- `https://github.com/AveYo/MediaCreationTool.bat`

## Dev memo

### Rebuild app list

```powershell
Import-Module -Name "$PWD\lib.psm1"
$rootDir = "$PWD\10.0.22621.1"

Convert-WimInfo "$rootDir\WimInfo.log"

$list = Convert-ProvisionedAppxPackages "$rootDir\index-6_ProvisionedAppxPackages.log"
$list.Keys.ForEach({"`"$_`" = `"$($list.$_)`""}) -join "`r`n"

$list = Convert-Packages "$rootDir\index-6_Packages.log"
$list.ForEach({"`"$_`""})
```

### Usages

```powershell
powershell -ExecutionPolicy Bypass -File Desktop\windows-iso-builder\10.0.22621.1\build.ps1

dism /image:C:\Users\admin\AppData\Local\Temp\windows-iso-builder_10.0.22621.1_scratchdir_index-6 /Remove-ProvisionedAppxPackage /PackageName:Clipchamp.Clipchamp_2.2.8.0_neutral_~_yxz26nhyzhsrt
dism /image:C:\Users\admin\AppData\Local\Temp\windows-iso-builder_10.0.22621.1_scratchdir_index-6 /Remove-Package /PackageName:Microsoft-Windows-InternetExplorer-Optional-Package~31bf3856ad364e35~amd64~en-US~11.0.22621.1

dism /get-mountedwiminfo
Get-WindowsImage -Mounted

reg unload "HKLM\_DEFAULT"
reg unload "HKLM\_SOFTWARE"
reg unload "HKLM\_SYSTEM"
reg unload "HKU\_mount"

dism /unmount-image /mountdir:c:\Users\admin\AppData\Local\Temp\windows-iso-builder_10.0.22621.1_scratchdir_index-6 /discard
dism /unmount-image /mountdir:c:\Users\admin\AppData\Local\Temp\windows-iso-builder_10.0.22621.1_scratchdir_index-6 /commit
dism /unmount-image /mountdir:c:\Users\admin\AppData\Local\Temp\windows-iso-builder_10.0.22621.1_scratchdir_index-6.boot /discard
dism /cleanup-wim
#REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WIMMount\Mounted Images

dism /Get-WimInfo /WimFile:d:\sources\install.wim /index:6
dism /Get-WimInfo /WimFile:d:\sources\boot.wim

Remove-Item c:\Users\admin\AppData\Local\Temp\windows-iso-builder_10.0.22621.1_image_D -Recurse -Force
Remove-Item c:\Users\admin\AppData\Local\Temp\windows-iso-builder_10.0.22621.1_scratchdir_index-6 -Recurse -Force
```
