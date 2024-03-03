$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Log "Powershell version must greater than 5"
    exit 2
}

$PROJECT_ID = "windows-iso-builder"
$DEBUG = $true
$BUILDER_ID = "${PROJECT_ID}_$((Get-Item $PSScriptRoot).Basename)"

Import-Module -Name "$(Split-Path $PSScriptRoot -Parent)\lib"
function Log ([string]$s) {
    Write-Host "[$BUILDER_ID] $s"
}
function Exec-Command ([string]$s) {
    if ($DEBUG) {
        Log "Invoke: $s"
    }
    try {
        Invoke-Expression $s
        if ($LASTEXITCODE -ne 0 -And $LASTEXITCODE -ne $null) {
            Log "Execute command exitcode is not 0: $LASTEXITCODE"
            exit 2
        }
    } catch {
        Log "Execute command failed: $s"
        exit 2
    }
}
function Exec-Command-With-Logger ([string]$s, [string]$f) {
    if ($DEBUG) {
        Log "Invoke: $s"
    }
    try {
        $result = Invoke-Expression $s
        if ($LASTEXITCODE -ne 0 -And $LASTEXITCODE -ne $null) {
            Log "Execute command exitcode is not 0: $LASTEXITCODE"
            exit 2
        }
        $result > "$PSScriptRoot\$f"
        Log "Dump result to $PSScriptRoot\$f"
    } catch {
        Log "Execute command failed: $s"
        exit 2
    }
}
$drivers = $(Get-Volume).GetEnumerator() | Where-Object {
    $_.DriveType -match "CD-ROM"
} | Select-Object DriveLetter, FileSystemLabel, DriveType, Size
if (@($drivers).Length -eq 0) {
	Log "Mounted CD-ROM not found, please mount the iso file via ``File Explorer``"
    exit 2
}
if (@($drivers).Length -eq 1) {
    $defaultValue = $drivers[0].DriveLetter
} else {
    $defaultValue = ''
}
$drivers | Format-Table -AutoSize
if ($defaultValue -eq '') {
    $DriveLetter = Read-Host "Please choose the drive letter for the Windows 11 image"
} else {
    $DriveLetter = Read-Host "Please choose the drive letter for the Windows 11 image or enter to accept the default [$($defaultValue)]"
    if ($DriveLetter -match "^\s*$") {
        $DriveLetter = $defaultValue
    }
}
if (
    !(Test-Path -Path "${DriveLetter}:\sources\boot.wim") -Or
    !(Test-Path -Path "${DriveLetter}:\sources\install.wim")
) {
	Log "Can`'t find Windows OS Installation files in the specified Drive Letter..."
	Log "Please enter the correct DVD Drive Letter..."
    exit 2
}
$SourceDir = "$env:TEMP\${BUILDER_ID}_image_$DriveLetter"

Log "Getting image information"
dism.exe /Get-WimInfo /wimfile:${DriveLetter}:\sources\install.wim > "$PSScriptRoot\WimInfo.log"
$wiminfo = Convert-WimInfo "$PSScriptRoot\WimInfo.log"
$wiminfo | Format-Table -AutoSize
$defaultValue = ($wiminfo.GetEnumerator() | ? { $_.Value -eq "Windows 11 Pro" }).Name
$index = Read-Host "Please choose the image index or enter to accept the default [$($defaultValue)]"
if ($index -match "^\s*$") {
    $index = $defaultValue
}
$ScratchDir = "$env:TEMP\${BUILDER_ID}_scratchdir_index-${index}"

if (Test-Path -Path "$SourceDir") {
    Log "$SourceDir exists, copy ignored"
} else {
    Exec-Command "mkdir `"$SourceDir`" -Force | Out-Null"
    Log "Copying Windows image from $DriveLetter to $SourceDir..."
    Exec-Command "xcopy.exe /E /I /H /R /Y /J ${DriveLetter}:\ $SourceDir"
    # Exec-Command "robocopy /E /COPY:DT /DCOPY:D /J /A-:R ${DriveLetter}:\ $SourceDir"
    # Exec-Command "attrib -r $SourceDir\sources\*.wim"
    Log "Copy complete!"
}
if (!(Test-Path -Path "$ScratchDir")) {
    Exec-Command "mkdir $ScratchDir -Force"
}
if (Test-Path -Path "$ScratchDir\*") {
    Log "$ScratchDir exists, ignore mounting install.wim"
} else {
    Log "Mounting Windows image. This may take a while."
    Exec-Command "dism.exe /mount-image /imagefile:$SourceDir\sources\install.wim /index:$index /mountdir:$ScratchDir"
    Log "Mounting complete!"
}

$apps = [ordered]@{
    "Clipchamp.Clipchamp" = "Clipchamp.Clipchamp_2.2.8.0_neutral_~_yxz26nhyzhsrt"
    "Microsoft.549981C3F5F10" = "Microsoft.549981C3F5F10_3.2204.14815.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.BingNews" = "Microsoft.BingNews_4.2.27001.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.BingWeather" = "Microsoft.BingWeather_4.53.33420.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.DesktopAppInstaller" = "Microsoft.DesktopAppInstaller_2022.310.2333.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.GamingApp" = "Microsoft.GamingApp_2021.427.138.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.GetHelp" = "Microsoft.GetHelp_10.2201.421.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.Getstarted" = "Microsoft.Getstarted_2021.2204.1.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.HEIFImageExtension" = "Microsoft.HEIFImageExtension_1.0.43012.0_x64__8wekyb3d8bbwe"
    # "Microsoft.HEVCVideoExtension" = "Microsoft.HEVCVideoExtension_1.0.50361.0_x64__8wekyb3d8bbwe"
    "Microsoft.MicrosoftOfficeHub" = "Microsoft.MicrosoftOfficeHub_18.2204.1141.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.MicrosoftSolitaireCollection" = "Microsoft.MicrosoftSolitaireCollection_4.12.3171.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.MicrosoftStickyNotes" = "Microsoft.MicrosoftStickyNotes_4.2.2.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.Paint" = "Microsoft.Paint_11.2201.22.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.People" = "Microsoft.People_2020.901.1724.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.PowerAutomateDesktop" = "Microsoft.PowerAutomateDesktop_10.0.3735.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.RawImageExtension" = "Microsoft.RawImageExtension_2.1.30391.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.ScreenSketch" = "Microsoft.ScreenSketch_2022.2201.12.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.SecHealthUI" = "Microsoft.SecHealthUI_1000.22621.1.0_x64__8wekyb3d8bbwe"
    # "Microsoft.StorePurchaseApp" = "Microsoft.StorePurchaseApp_12008.1001.113.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.Todos" = "Microsoft.Todos_2.54.42772.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.VCLibs.140.00" = "Microsoft.VCLibs.140.00_14.0.30704.0_x64__8wekyb3d8bbwe"
    # "Microsoft.VP9VideoExtensions" = "Microsoft.VP9VideoExtensions_1.0.50901.0_x64__8wekyb3d8bbwe"
    # "Microsoft.WebMediaExtensions" = "Microsoft.WebMediaExtensions_1.0.42192.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.WebpImageExtension" = "Microsoft.WebpImageExtension_1.0.42351.0_x64__8wekyb3d8bbwe"
    # "Microsoft.Windows.Photos" = "Microsoft.Windows.Photos_21.21030.25003.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.WindowsAlarms" = "Microsoft.WindowsAlarms_2022.2202.24.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.WindowsCalculator" = "Microsoft.WindowsCalculator_2020.2103.8.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.WindowsCamera" = "Microsoft.WindowsCamera_2022.2201.4.0_neutral_~_8wekyb3d8bbwe"
    "microsoft.windowscommunicationsapps" = "microsoft.windowscommunicationsapps_16005.14326.20544.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.WindowsFeedbackHub" = "Microsoft.WindowsFeedbackHub_2022.106.2230.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.WindowsMaps" = "Microsoft.WindowsMaps_2022.2202.6.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.WindowsNotepad" = "Microsoft.WindowsNotepad_11.2112.32.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.WindowsSoundRecorder" = "Microsoft.WindowsSoundRecorder_2021.2103.28.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.WindowsStore" = "Microsoft.WindowsStore_22204.1400.4.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.WindowsTerminal" = "Microsoft.WindowsTerminal_3001.12.10983.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.Xbox.TCUI" = "Microsoft.Xbox.TCUI_1.23.28004.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.XboxGameOverlay" = "Microsoft.XboxGameOverlay_1.47.2385.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.XboxGamingOverlay" = "Microsoft.XboxGamingOverlay_2.622.3232.0_neutral_~_8wekyb3d8bbwe"
    # "Microsoft.XboxIdentityProvider" = "Microsoft.XboxIdentityProvider_12.50.6001.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.XboxSpeechToTextOverlay" = "Microsoft.XboxSpeechToTextOverlay_1.17.29001.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.YourPhone" = "Microsoft.YourPhone_1.22022.147.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.ZuneMusic" = "Microsoft.ZuneMusic_11.2202.46.0_neutral_~_8wekyb3d8bbwe"
    "Microsoft.ZuneVideo" = "Microsoft.ZuneVideo_2019.22020.10021.0_neutral_~_8wekyb3d8bbwe"
    "MicrosoftCorporationII.QuickAssist" = "MicrosoftCorporationII.QuickAssist_2022.414.1758.0_neutral_~_8wekyb3d8bbwe"
    # "MicrosoftWindows.Client.WebExperience" = "MicrosoftWindows.Client.WebExperience_421.20070.195.0_neutral_~_cw5n1h2txyewy"
}
Exec-Command-With-Logger "dism.exe /Image:$ScratchDir /Get-ProvisionedAppxPackages" "index-${index}_ProvisionedAppxPackages.log"
$current_apps = Convert-ProvisionedAppxPackages "$PSScriptRoot\index-${index}_ProvisionedAppxPackages.log"
Log "Performing removal of applications..."
$progress = 0
foreach ($app in $apps.GetEnumerator()) {
    $percent = '{0:n2}' -f ($progress / $apps.PSBase.Count *100)
    # Write-Progress -Activity "Removing app: $($app.Name)..." -Status "$percent%" -PercentComplete $percent
    foreach ($current_app in $current_apps.GetEnumerator()) {
        if ($current_app.Name -eq $app.Name) {
            Log "Removing app: $($app.Name)..."
            Exec-Command "dism.exe /image:$ScratchDir /Remove-ProvisionedAppxPackage /PackageName:$($app.Value)"
            $progress++
            break
        }
    }
    Log "$($app.Name) not found in current image, skip removing"
    $progress++
}
Log "Removing of system apps complete!"

$system_packages = @(
    # "Microsoft-OneCore-ApplicationModel-Sync-Desktop-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-OneCore-DirectX-Database-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Client-LanguagePack-Package~31bf3856ad364e35~amd64~en-US~10.0.22621.2861"
    # "Microsoft-Windows-Ethernet-Client-Intel-E1i68x64-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Ethernet-Client-Intel-E2f68-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Ethernet-Client-Realtek-Rtcx21x64-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Ethernet-Client-Vmware-Vmxnet3-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-FodMetadata-Package~31bf3856ad364e35~amd64~~10.0.22621.1"
    # "Microsoft-Windows-Foundation-Package~31bf3856ad364e35~amd64~~10.0.22621.1"
    # "Microsoft-Windows-Hello-Face-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-InternetExplorer-Optional-Package~31bf3856ad364e35~amd64~en-US~11.0.22621.1" #
    "Microsoft-Windows-InternetExplorer-Optional-Package~31bf3856ad364e35~amd64~~11.0.22621.2861"
    "Microsoft-Windows-Kernel-LA57-FoD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-LanguageFeatures-Basic-en-us-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    "Microsoft-Windows-LanguageFeatures-Handwriting-en-us-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    "Microsoft-Windows-LanguageFeatures-OCR-en-us-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    "Microsoft-Windows-LanguageFeatures-Speech-en-us-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    "Microsoft-Windows-LanguageFeatures-TextToSpeech-en-us-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-MediaPlayer-Package~31bf3856ad364e35~amd64~en-US~10.0.22621.2792" #
    "Microsoft-Windows-MediaPlayer-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-MediaPlayer-Package~31bf3856ad364e35~wow64~en-US~10.0.22621.1" #
    # "Microsoft-Windows-MediaPlayer-Package~31bf3856ad364e35~wow64~~10.0.22621.2861" #
    # "Microsoft-Windows-Notepad-System-FoD-Package~31bf3856ad364e35~amd64~en-US~10.0.22621.1"
    # "Microsoft-Windows-Notepad-System-FoD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Notepad-System-FoD-Package~31bf3856ad364e35~wow64~en-US~10.0.22621.1"
    # "Microsoft-Windows-Notepad-System-FoD-Package~31bf3856ad364e35~wow64~~10.0.22621.2861"
    # "Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~amd64~en-US~10.0.22621.1"
    # "Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~wow64~en-US~10.0.22621.1"
    # "Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~wow64~~10.0.22621.2861"
    # "Microsoft-Windows-Printing-PMCPPC-FoD-Package~31bf3856ad364e35~amd64~en-US~10.0.22621.1"
    # "Microsoft-Windows-Printing-PMCPPC-FoD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~amd64~en-US~10.0.22621.1"
    # "Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~wow64~en-US~10.0.22621.1"
    # "Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~wow64~~10.0.22621.2861"
    "Microsoft-Windows-TabletPCMath-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    "Microsoft-Windows-Wallpaper-Content-Extended-FoD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Broadcom-Bcmpciedhd63-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Broadcom-Bcmwl63a-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Broadcom-Bcmwl63al-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Intel-Netwbw02-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Intel-Netwew00-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Intel-Netwew01-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Intel-Netwlv64-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Intel-Netwns64-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Intel-Netwsw00-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Intel-Netwtw02-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Intel-Netwtw04-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Intel-Netwtw06-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Intel-Netwtw08-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Intel-Netwtw10-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Marvel-Mrvlpcie8897-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Qualcomm-Athw8x-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Qualcomm-Athwnx-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Qualcomm-Qcamain10x64-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Ralink-Netr28x-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Realtek-Rtl8187se-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Realtek-Rtl8192se-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Realtek-Rtl819xp-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Realtek-Rtl85n64-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Realtek-Rtwlane-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Realtek-Rtwlane01-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-Wifi-Client-Realtek-Rtwlane13-FOD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-WMIC-FoD-Package~31bf3856ad364e35~amd64~en-US~10.0.22621.1"
    # "Microsoft-Windows-WMIC-FoD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-WMIC-FoD-Package~31bf3856ad364e35~wow64~en-US~10.0.22621.1"
    # "Microsoft-Windows-WMIC-FoD-Package~31bf3856ad364e35~wow64~~10.0.22621.2861"
    # "Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~amd64~en-US~10.0.22621.1"
    # "Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~wow64~en-US~10.0.22621.1"
    # "Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~wow64~~10.0.22621.2861"
    # "OpenSSH-Client-Package~31bf3856ad364e35~amd64~~10.0.22621.2861"
    # "Package_for_DotNetRollup_481~31bf3856ad364e35~amd64~~10.0.9206.1"
    # "Package_for_KB5027397~31bf3856ad364e35~amd64~~22621.2355.1.1"
    # "Package_for_RollupFix~31bf3856ad364e35~amd64~~22621.2861.1.6"
    # "Package_for_ServicingStack_2567~31bf3856ad364e35~amd64~~22621.2567.1.1"
)
Exec-Command-With-Logger "dism.exe /Image:$ScratchDir /Get-Packages" "index-${index}_Packages.log"
$current_system_packages = Convert-Packages "$PSScriptRoot\index-${index}_Packages.log"
Log "Now proceeding to removal of system packages..."
for ($i = 0; $i -lt $system_packages.Length; $i++) {
    $percent = '{0:n2}' -f ($i + 1 / $system_packages.Length *100)
    $v = $system_packages[$i]
    # Write-Progress -Activity "Removing $v..." -Status "$percent%" -PercentComplete $percent
    for ($j = 0; $j -lt $current_system_packages.Length; $j++) {
        $vv = $current_system_packages[$j]
        if ($vv -eq $v) {
            Log "Removing $v..."
            Exec-Command "dism.exe /image:$ScratchDir /Remove-Package /PackageName:$v"
            break
        }
    }
    Log "$v not found in current image, skip removing."
}
Log "Removing Edge:"
if (Test-Path -Path "$ScratchDir\Program Files (x86)\Microsoft\Edge") {
    Exec-Command "Remove-Item `"$ScratchDir\Program Files (x86)\Microsoft\Edge`" -Recurse -Force"
}
if (Test-Path -Path "$ScratchDir\Program Files (x86)\Microsoft\EdgeUpdate") {
    Exec-Command "Remove-Item `"$ScratchDir\Program Files (x86)\Microsoft\EdgeUpdate`" -Recurse -Force"
}

Log "Removing OneDrive:"
if (Test-Path -Path "$ScratchDir\Windows\System32\OneDriveSetup.exe") {
    Exec-Command "takeown /f `"$ScratchDir\Windows\System32\OneDriveSetup.exe`""
    Exec-Command "icacls `"$ScratchDir\Windows\System32\OneDriveSetup.exe`" /grant Administrators:F /T /C"
    Exec-Command "Remove-Item `"$ScratchDir\Windows\System32\OneDriveSetup.exe`" -Force"
}

Log "Removal complete!"

Log "Optimize-ProvisionedAppxPackages"
Exec-Command "dism.exe /Image:$ScratchDir /Optimize-ProvisionedAppxPackages"

function Load-Reg ([string]$ScratchDir) {
    Log "Loading registry..."
    # Exec-Command "reg load `"HKLM\_COMPONENTS`" `"$ScratchDir\Windows\System32\config\COMPONENTS`""
    Exec-Command "reg load `"HKLM\_DEFAULT`" `"$ScratchDir\Windows\System32\config\DEFAULT`""
    Exec-Command "reg load `"HKLM\_SOFTWARE`" `"$ScratchDir\Windows\System32\config\SOFTWARE`""
    Exec-Command "reg load `"HKLM\_SYSTEM`" `"$ScratchDir\Windows\System32\config\SYSTEM`""
    Exec-Command "reg load `"HKU\_mount`" `"$ScratchDir\Users\Default\NTUSER.dat`""
}
function Unload-Reg {
    Log "Unloading Registry..."
    # Exec-Command "reg unload `"HKLM\_COMPONENTS`""
    Exec-Command "reg unload `"HKLM\_DEFAULT`""
    Exec-Command "reg unload `"HKLM\_SOFTWARE`""
    Exec-Command "reg unload `"HKLM\_SYSTEM`""
    Exec-Command "reg unload `"HKU\_mount`""
}
Load-Reg "$ScratchDir"

Log "Allow Windows 11 to be installed without internet connection"
Exec-Command "Reg add `"HKLM\_SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE`" /v BypassNRO /t REG_DWORD /d 1 /f"

Log "Start optimizing via reg..." # some is based on autounaattend.xml, see: https://schneegans.de/windows/unattend-generator/

# # Based on autounattend.xml
# Log "Disable Windows Defender"

# Based on autounattend.xml
Log "Disable System Protection / System Restore"

Log "Enable long paths"
Exec-Command "Reg add `"HKLM\_SYSTEM\CurrentControlSet\Control\FileSystem`" /v LongPathsEnabled /t REG_DWORD /d 1 /f"

# # Based on autounattend.xml
# Log "Enable Remote Desktop services (RDP)"

# # Based on autounattend.xml
# Log "Harden ACLs"

# # Based on autounattend.xml
# Log "Allow execution of PowerShell script files"

# Based on autounattend.xml
Log "Do not update Last Access Time stamp"

Log "Do not reboot with users signed in"
Exec-Command "Reg add `"HKLM\_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`" /v AUOptions /t REG_DWORD /d 4 /f"
Exec-Command "Reg add `"HKLM\_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f"

# Based on autounattend.xml
Log "Turn off system sounds"

Log "Run shell script when users log on for the first time"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\Runonce`" /v UserFirstLogon /t REG_SZ /d C:\Windows\Setup\Scripts\UserFirstLogon.cmd /f"
if (!(Test-Path -Path "$ScratchDir\Windows\Setup\Scripts")) {
    Exec-Command "mkdir `"$ScratchDir\Windows\Setup\Scripts`""
}
Exec-Command "Copy-Item `"$PSScriptRoot\UserFirstLogon.cmd`" -Destination `"$ScratchDir\Windows\Setup\Scripts\UserFirstLogon.cmd`""

Log "Disable app suggestions"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v ContentDeliveryAllowed /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v FeatureManagementEnabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v OEMPreInstalledAppsEnabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v PreInstalledAppsEverEnabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SoftLandingEnabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContentEnabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-338387Enabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-353698Enabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f"
Exec-Command "Reg add `"HKLM\_SOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 0 /f"

Log "Disable widgets"
Exec-Command "Reg add `"HKLM\_SOFTWARE\Policies\Microsoft\Dsh`" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f"

# Based on autounattend.xml
# Log "Audit process creation events"

function Bypass-Check {
    Log "Bypass Windows 11 requirements check (TPM, Secure Boot, etc.)"
    Exec-Command "Reg add `"HKLM\_SYSTEM\Setup\LabConfig`" /v BypassTPMCheck /t REG_DWORD /d 1 /f"
    Exec-Command "Reg add `"HKLM\_SYSTEM\Setup\LabConfig`" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f"
    Exec-Command "Reg add `"HKLM\_SYSTEM\Setup\LabConfig`" /v BypassStorageCheck /t REG_DWORD /d 1 /f"
    Exec-Command "Reg add `"HKLM\_SYSTEM\Setup\LabConfig`" /v BypassCPUCheck /t REG_DWORD /d 1 /f"
    Exec-Command "Reg add `"HKLM\_SYSTEM\Setup\LabConfig`" /v BypassRAMCheck /t REG_DWORD /d 1 /f"
    Exec-Command "Reg add `"HKLM\_SYSTEM\Setup\LabConfig`" /v BypassDiskCheck /t REG_DWORD /d 1 /f"
    Log "hide unsupported nag on desktop" # see: https://github.com/AveYo/MediaCreationTool.bat/blob/main/bypass11/AutoUnattend.xml
    Exec-Command "Reg add `"HKLM\_DEFAULT\Control Panel\UnsupportedHardwareNotificationCache`" /v SV1 /t REG_DWORD /d 0 /f"
    Exec-Command "Reg add `"HKLM\_DEFAULT\Control Panel\UnsupportedHardwareNotificationCache`" /v SV2 /t REG_DWORD /d 0 /f"
    Exec-Command "Reg add `"HKU\_mount\Control Panel\UnsupportedHardwareNotificationCache`" /v SV1 /t REG_DWORD /d 0 /f"
    Exec-Command "Reg add `"HKU\_mount\Control Panel\UnsupportedHardwareNotificationCache`" /v SV2 /t REG_DWORD /d 0 /f"
    Exec-Command "Reg add `"HKLM\_SYSTEM\Setup\MoSetup`" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f"
}
Bypass-Check

Log "reg cleanup: Dev Home (since 23H2)"
Exec-Command "Reg delete `"HKLM\_SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate`" /f"

Log "reg cleanup: Notepad (modern)"
Exec-Command "Reg add `"HKU\_mount\Software\Microsoft\Notepad`" /v ShowStoreBanner /t REG_DWORD /d 0 /f"

Log "reg cleanup: OneDrive"
Exec-Command "Reg delete `"HKU\_mount\Software\Microsoft\Windows\CurrentVersion\Run`" /v OneDriveSetup /f"

Log "reg cleanup: Outlook for Windows (since 23H2)"
Exec-Command "Reg delete `"HKLM\_SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate`" /f"

Log "reg cleanup: Teams"

# https://learn.microsoft.com/en-us/archive/msdn-technet-forums/e718a560-2908-4b91-ad42-d392e7f8f1ad
enable-privilege SeTakeOwnershipPrivilege
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
    "_SOFTWARE\Microsoft\Windows\CurrentVersion\Communications",
    [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
    [System.Security.AccessControl.RegistryRights]::takeownership
)

# You must get a blank acl for the key b/c you do not currently have access
$acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
$me = [System.Security.Principal.NTAccount]"BUILTIN\Administrators"
$acl.SetOwner($me)
$key.SetAccessControl($acl)

# After you have set owner you need to get the acl with the perms so you can modify it.
$acl = $key.GetAccessControl()
$rule = New-Object System.Security.AccessControl.RegistryAccessRule ("BUILTIN\Administrators","FullControl",@("ObjectInherit","ContainerInherit"),"None","Allow")
$acl.SetAccessRule($rule)
$key.SetAccessControl($acl)

Exec-Command "Reg add `"HKLM\_SOFTWARE\Microsoft\Windows\CurrentVersion\Communications`" /v ConfigureChatAutoInstall /t REG_DWORD /d 0 /f"

# Restore permission back to read
$acl = $key.GetAccessControl()
$rule = New-Object System.Security.AccessControl.RegistryAccessRule ("BUILTIN\Administrators","ReadKey",@("ObjectInherit","ContainerInherit"),"None","Allow")
$acl.SetAccessRule($rule)
$key.SetAccessControl($acl)

# Restore owner back to TrustedInstaller
$user = [System.Security.Principal.NTAccount]"NT SERVICE\TrustedInstaller"
$acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
$acl.SetOwner($user)
enable-privilege SeRestorePrivilege
$key.SetAccessControl($acl)

$key.Close()

Exec-Command "Reg add `"HKLM\_SOFTWARE\Policies\Microsoft\Windows\Windows Chat`" /v ChatIcon /t REG_DWORD /d 3 /f"
Exec-Command "Reg add `"HKU\_mount\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced`" /v TaskbarMn /t REG_DWORD /d 0 /f"

function Reset-Pins {
    Exec-Command "Reg add `"HKLM\_SOFTWARE\Microsoft\PolicyManager\current\device\Start`" /v ConfigureStartPins /t REG_SZ /d `"{ \```"pinnedList\```": [] }`" /f"
    Exec-Command "Reg add `"HKLM\_SOFTWARE\Microsoft\PolicyManager\current\device\Start`" /v ConfigureStartPins_ProviderSet /t REG_DWORD /d 1 /f"
    Exec-Command "Reg add `"HKLM\_SOFTWARE\Microsoft\PolicyManager\current\device\Start`" /v ConfigureStartPins_WinningProvider /t REG_SZ /d B5292708-1619-419B-9923-E5D9F3925E71 /f"
    Exec-Command "Reg add `"HKLM\_SOFTWARE\Microsoft\PolicyManager\providers\B5292708-1619-419B-9923-E5D9F3925E71\default\Device\Start`" /v ConfigureStartPins /t REG_SZ /d `"{ \```"pinnedList\```": [] }`" /f"
    Exec-Command "Reg add `"HKLM\_SOFTWARE\Microsoft\PolicyManager\providers\B5292708-1619-419B-9923-E5D9F3925E71\default\Device\Start`" /v ConfigureStartPins_LastWrite /t REG_DWORD /d 1 /f"
}
Reset-Pins

# # Log "Disabling Reserved Storage:"
# Exec-Command "Reg add `"HKLM\_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager`" /v ShippedWithReserves /t REG_DWORD /d 0 /f

Exec-Command "Copy-Item `"$PSScriptRoot\autounattend.xml`" `"$ScratchDir\Windows\System32\Sysprep\autounattend.xml`""

Log "Optimizing via reg complete!"

Unload-Reg

Log "Cleaning up image..."
Exec-Command "dism.exe /image:$ScratchDir /Cleanup-Image /StartComponentCleanup /ResetBase"
Log "Cleanup complete."

Log "Unmounting image..."
Exec-Command "dism.exe /unmount-image /mountdir:$ScratchDir /commit"

Log "Exporting image..."
Exec-Command "dism.exe /Export-Image /SourceImageFile:$SourceDir\sources\install.wim /SourceIndex:$index /DestinationImageFile:$SourceDir\sources\install2.wim /compress:max"

Log "Windows image completed. Continuing with boot.wim."

if (!(Test-Path -Path "$ScratchDir.boot")) {
    Exec-Command "mkdir $ScratchDir.boot -Force"
}
if (Test-Path -Path "$ScratchDir.boot\*") {
    Log "$ScratchDir.boot exists, ignore mounting boot.wim"
} else {
    Log "Mounting boot image:"
    Exec-Command "dism.exe /mount-image /imagefile:$SourceDir\sources\boot.wim /index:2 /mountdir:$ScratchDir.boot"
    Log "Mounting complete!"
}

Load-Reg "$ScratchDir.boot"
Bypass-Check
Unload-Reg

Log "Unmounting image..."
Exec-Command "dism.exe /unmount-image /mountdir:$ScratchDir.boot /commit"

Log "the $PROJECT_ID image is now completed. Proceeding with the making of the ISO..."

Log "Copying unattended file for bypassing MS account on OOBE..."
Exec-Command "Copy-Item `"$PSScriptRoot\autounattend.xml`" `"$SourceDir\autounattend.xml`""

Log "Creating ISO image..."
Exec-Command "Remove-Item $SourceDir\sources\install.wim"
Exec-Command "Rename-Item $SourceDir\sources\install2.wim install.wim"
Exec-Command "oscdimg.exe -m -o -u2 -udfver102 -bootdata:`"2#p0,e,b$SourceDir\boot\etfsboot.com#pEF,e,b$SourceDir\efi\microsoft\boot\efisys.bin`" $SourceDir $($PWD.Path)\${PROJECT_ID}_index-${index}.iso"

Log "Creation completed!"

Read-Host -Prompt "Press any key to cleanup temp folders (or ctrl + c to exit without cleanup)..."
Log "Performing Cleanup..."
Exec-Command "Remove-Item $SourceDir -Recurse -Force"
Exec-Command "Remove-Item $ScratchDir -Recurse -Force"
Exec-Command "Remove-Item $ScratchDir.boot -Recurse -Force"
