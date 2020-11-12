#############################################################################################################################
#
# ESXi-Customizer-PS.ps1 - a script to build a customized ESXi installation ISO using ImageBuilder
#
# Version:       2.8.1
# Author:        Andreas Peetz (ESXi-Customizer-PS@v-front.de)
# Info/Tutorial: https://esxi-customizer-ps.v-front.de/
#
# Contributors:  Alex Lopez, Andre Pett, Vladislav Grishenko
#
# License:
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# A copy of the GNU General Public License is available at http://www.gnu.org/licenses/.
#
#############################################################################################################################

param(
    [string]$iZip = "",
    [string[]]$pkgDir = @(),
    [string]$outDir = $(Split-Path $MyInvocation.MyCommand.Path),
    [string]$ipname = "",
    [string]$ipvendor = "",
    [string]$ipdesc = "",
    [switch]$vft = $false,
    [string[]]$dpt = @(),
    [string[]]$load = @(),
    [string[]]$remove = @(),
    [switch]$test = $false,
    [switch]$sip = $false,
    [switch]$nsc = $false,
    [switch]$help = $false,
    [switch]$ozip = $false,
    [switch]$v50 = $false,
    [switch]$v51 = $false,
    [switch]$v55 = $false,
    [switch]$v60 = $false,
    [switch]$v65 = $false,
    [switch]$v67 = $false,
    [switch]$v70 = $false,
    [switch]$update = $false,
    [string]$pZip = "",
    [string]$log = ($env:TEMP + "\ESXi-Customizer-PS-" + $PID + ".log")
)

# Constants
$ScriptName = "ESXi-Customizer-PS"
$ScriptVersion = "2.8.1"
$ScriptURL = "https://ESXi-Customizer-PS.v-front.de"

$AccLevel = @{"VMwareCertified" = 1; "VMwareAccepted" = 2; "PartnerSupported" = 3; "CommunitySupported" = 4}

# Online depot URLs
$vmwdepotURL = "https://hostupdate.vmware.com/software/VUM/PRODUCTION/main/vmw-depot-index.xml"
$vftdepotURL = "https://vibsdepot.v-front.de/"

# Function to update/add VIB package
function AddVIB2Profile($vib) {
    $AddVersion = $vib.Version
    $ExVersion = ($MyProfile.VibList | where { $_.Name -eq $vib.Name }).Version
    
    # Check for vib replacements
    $ExName = ""
    if ($ExVersion -eq $null) {
        foreach ($replaces in $vib.replaces) {
            $ExVib = $MyProfile.VibList | where { $_.Name -eq $replaces }
            if ($ExVib -ne $null) {
                $ExName = $ExVib.Name + " "
                $ExVersion = $ExVib.Version
                break
            }
        }
    }
    
    if ($AccLevel[$vib.AcceptanceLevel.ToString()] -gt $AccLevel[$MyProfile.AcceptanceLevel.ToString()]) {
        write-host -F Yellow -nonewline (" [New AcceptanceLevel: " + $vib.AcceptanceLevel + "]")
        $MyProfile.AcceptanceLevel = $vib.AcceptanceLevel
    }
    If ($MyProfile.VibList -contains $vib) {
        write-host -F Yellow " [IGNORED, already added]"
    } else {
        Add-EsxSoftwarePackage -SoftwarePackage $vib -Imageprofile $MyProfile -force -ErrorAction SilentlyContinue | Out-Null
        if ($?) {
            if ($ExVersion -eq $null) {
                write-host -F Green " [OK, added]"
            } else {
                write-host -F Green (" [OK, replaced " + $ExName + $ExVersion + "]")
            }
        } else {
            write-host -F Red " [FAILED, invalid package?]"
        }
    }
}

# Function to test if entered string is numeric
function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
}

# Clean-up function
function cleanup() {
    Stop-Transcript | Out-Null
    if ($DefaultSoftwaredepots) { Remove-EsxSoftwaredepot $DefaultSoftwaredepots }
}

# Write info and help if requested
write-host ("`nThis is " + $ScriptName + " Version " + $ScriptVersion + " (visit " + $ScriptURL + " for more information!)")
if ($help) {
    write-host "`nUsage:"
    write-host "  ESXi-Customizer-PS [-help] |  [-izip <bundle> [-update]] [-sip] [-v70|-v67|-v65|-v60|-v55|-v51|-v50]"
    write-host "                                [-ozip] [-pkgDir <dir>[,...]] [-outDir <dir>] [-vft] [-dpt depot1[,...]]"
    write-host "                                [-load vib1[,...]] [-remove vib1[,...]] [-log <file>] [-ipname <name>]"
    write-host "                                [-ipdesc <desc>] [-ipvendor <vendor>] [-nsc] [-test]"
    write-host "`nOptional parameters:"
    write-host "   -help              : display this help"
    write-host "   -izip <bundle>     : use the VMware Offline bundle <bundle> as input instead of the Online depot"
    write-host "   -update            : only with -izip, updates a local bundle with an ESXi patch from the VMware Online depot,"
    write-host "                        combine this with the matching ESXi version selection switch"
    write-host "   -pzip              : use an Offline patch bundle instead of the Online depot with -update."
    write-host "   -pkgDir <dir>[,...]: local directories of Offline bundles and/or VIB files to add (if any, no default)"
    write-host "   -ozip              : output an Offline bundle instead of an installation ISO"
    write-host "   -outDir <dir>      : directory to store the customized ISO or Offline bundle (the default is the"
    write-host "                        script directory. If specified the log file will also be moved here.)"
    write-host "   -vft               : connect the V-Front Online depot"
    write-host "   -dpt depot1[,...]  : connect additional Online depots by URL or local Offline bundles by file name"
    write-host "   -load vib1[,...]   : load additional packages from connected depots or Offline bundles"
    write-host "   -remove vib1[,...] : remove named VIB packages from the custom Imageprofile"
    write-host "   -sip               : select an Imageprofile from the current list"
    write-host "                        (default = auto-select latest available standard profile)"
    write-host "   -v70 |"
    write-host "   -v67 | -v65 | -v60 |"
    write-host "   -v55 | -v51 | -v50 : Use only ESXi 7.0/6.7/6.5/6.0/5.5/5.1/5.0 Imageprofiles as input, ignore other versions"
    write-host "   -nsc               : use -NoSignatureCheck with export"
    write-host "   -log <file>        : Use custom log file <file>"
    write-host "   -ipname <name>"
    write-host "   -ipdesc <desc>"
    write-host "   -ipvendor <vendor> : provide a name, description and/or vendor for the customized"
    write-host "                        Imageprofile (the default is derived from the cloned input Imageprofile)"
    write-host "   -test              : skip package download and image build (for testing)`n"
    exit
} else {
    write-host "(Call with -help for instructions)"
    if (!($PSBoundParameters.ContainsKey('log')) -and $PSBoundParameters.ContainsKey('outDir')) {
        write-host ("`nTemporarily logging to " + $log + " ...")
    } else {
        write-host ("`nLogging to " + $log + " ...")
    }
    # Stop active transcript
    try { Stop-Transcript | out-null } catch {}
    # Start own transcript
    try { Start-Transcript -Path $log -Force -Confirm:$false | Out-Null } catch {
        write-host -F Red "`nFATAL ERROR: Log file cannot be opened. Bad file path or missing permission?`n"
        exit
    }
}

# The main try ...

$isModule = @{}
try {

# Check for and load required modules/snapins
foreach ($comp in "VMware.VimAutomation.Core", "VMware.ImageBuilder", "VMware.PowerCLI") {
    if (Get-Module -ListAvailable -Name $comp -ErrorAction:SilentlyContinue) {
		$isModule[$comp] = $true
        if (!(Get-Module -Name $comp -ErrorAction:SilentlyContinue)) {
            if (!(Import-Module -PassThru -Name $comp -ErrorAction:SilentlyContinue)) {
                write-host -F Red "`nFATAL ERROR: Failed to import the $comp module!`n"
                exit
            }
        }
    } else {
		$isModule[$comp] = $false
        if (Get-PSSnapin -Registered -Name $comp -ErrorAction:SilentlyContinue) {
            if (!(Get-PSSnapin -Name $comp -ErrorAction:SilentlyContinue)) {
                if (!(Add-PSSnapin -PassThru -Name $comp -ErrorAction:SilentlyContinue)) {
                    write-host -F Red "`nFATAL ERROR: Failed to add the $comp snap-in!`n"
                    exit
                }
            }
        } else {
            write-host -F Red "`nFATAL ERROR: $comp is not available as a module or snap-in! It looks like there is no compatible version of PowerCLI installed!`n"
            exit
        }
    }
}

# Parameter sanity check
if ( ($v50 -and ($v51 -or $v55 -or $v60 -or $v65 -or $v67 -or $v70)) -or ($v51 -and ($v55 -or $v60 -or $v65 -or $v67 -or $v70)) -or ($v55 -and ($v60 -or $v65 -or $v67 -or $v70)) -or ($v60 -and ($v65 -or $v67 -or $70)) -or ($v65 -and ($v67 -or $v70)) -or ($v70 -and ($v51 -or $v55 -or $v60 -or $v65 -or $v67)) ) {
    write-host -F Yellow "`nWARNING: Multiple ESXi versions specified. Highest version will take precedence!"
}
if ($update -and ($izip -eq "")) {
    write-host -F Red "`nFATAL ERROR: -update requires -izip!`n"
    exit
}

# Check PowerShell and PowerCLI version
if (!(Test-Path variable:PSVersionTable)) {
    write-host -F Red "`nFATAL ERROR: This script requires at least PowerShell version 2.0!`n"
    exit
}
$psv = $PSVersionTable.PSVersion | select Major,Minor

if ($isModule["VMware.VimAutomation.Core"]) {
	$pcmv = (Get-Module VMware.PowerCLI).Version | select Major,Minor,Build,Revision
	write-host -F Yellow ("`nRunning with PowerShell version " + $psv.Major + "." + $psv.Minor + " and VMware PowerCLI version " + $pcmv.Major + "." + $pcmv.Minor + "." + $pcmv.Build + " build " + $pcmv.Revision )
} else {
	$pcv = Get-PowerCLIVersion | select major,minor,UserFriendlyVersion
	write-host -F Yellow ("`nRunning with PowerShell version " + $psv.Major + "." + $psv.Minor + " and " + $pcv.UserFriendlyVersion)
	if ( ($pcv.major -lt 5) -or (($pcv.major -eq 5) -and ($pcv.minor -eq 0)) ) {
		write-host -F Red "`nFATAL ERROR: This script requires at least PowerCLI version 5.1 !`n"
		exit
	}
}

if ($update) {
    # Try to add Offline bundle specified by -izip
    write-host -nonewline "`nAdding Base Offline bundle $izip (to be updated)..."
    if ($upddepot = Add-EsxSoftwaredepot $izip) {
        write-host -F Green " [OK]"
    } else {
        write-host -F Red "`nFATAL ERROR: Cannot add Base Offline bundle!`n"
        exit
    }
    if (!($CloneIP = Get-EsxImageprofile -Softwaredepot $upddepot)) {
        write-host -F Red "`nFATAL ERROR: No Imageprofiles found in Base Offline bundle!`n"
        exit
    }
    if ($CloneIP -is [system.array]) {
        # Input Offline bundle includes multiple Imageprofiles. Pick only the latest standard profile:
        write-host -F Yellow "Warning: Input Offline Bundle contains multiple Imageprofiles. Will pick the latest standard profile!"
        $CloneIP = @( $CloneIP | Sort-Object -Descending -Property @{Expression={$_.Name.Substring(0,10)}},@{Expression={$_.CreationTime.Date}},Name )[0]
    }
}

if ($update -and $pzip -ne "") {
   $vmwdepotURL = $pZip
}

if (($izip -eq "") -or $update) {
    # Connect the VMware ESXi base depot
    write-host -nonewline "`nConnecting the VMware ESXi Software depot ..."
    if ($basedepot = Add-EsxSoftwaredepot $vmwdepotURL) {
        write-host -F Green " [OK]"
    } else {
        write-host -F Red "`nFATAL ERROR: Cannot add VMware ESXi Online depot. Please check your Internet connectivity and/or proxy settings!`n"
        exit
    }
} else {
    # Try to add Offline bundle specified by -izip
    write-host -nonewline "`nAdding base Offline bundle $izip ..."
    if ($basedepot = Add-EsxSoftwaredepot $izip) {
        write-host -F Green " [OK]"
    } else {
        write-host -F Red "`nFATAL ERROR: Cannot add VMware base Offline bundle!`n"
        exit
    }
}

if ($vft) {
    # Connect the V-Front Online depot
    write-host -nonewline "`nConnecting the V-Front Online depot ..."
    if ($vftdepot = Add-EsxSoftwaredepot $vftdepotURL) {
        write-host -F Green " [OK]"
    } else {
        write-host -F Red "`nFATAL ERROR: Cannot add the V-Front Online depot. Please check your internet connectivity and/or proxy settings!`n"
        exit
    }
}

if ($dpt -ne @()) {
	# Connect additional depots (Online depot or Offline bundle)
	$AddDpt = @()
	for ($i=0; $i -lt $dpt.Length; $i++ ) {
		write-host -nonewline ("`nConnecting additional depot " + $dpt[$i] + " ...")
		if ($AddDpt += Add-EsxSoftwaredepot $dpt[$i]) {
			write-host -F Green " [OK]"
		} else {
			write-host -F Red "`nFATAL ERROR: Cannot add Online depot or Offline bundle. In case of Online depot check your Internet"
			write-host -F Red "connectivity and/or proxy settings! In case of Offline bundle check file name, format and permissions!`n"
			exit
		}
	}

}

write-host -NoNewLine "`nGetting Imageprofiles, please wait ..."
$iplist = @()
if ($iZip -and !($update)) {
    Get-EsxImageprofile -Softwaredepot $basedepot | foreach { $iplist += $_ }
} else {
	if ($v70) {
		Get-EsxImageprofile "ESXi-7.0*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
	} else {
		if ($v67) {
			Get-EsxImageprofile "ESXi-6.7*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
		} else {
			if ($v65) {
				Get-EsxImageprofile "ESXi-6.5*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
			} else {
				if ($v60) {
					Get-EsxImageprofile "ESXi-6.0*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
				} else {
					if ($v55) {
						Get-EsxImageprofile "ESXi-5.5*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
					} else {
						if ($v51) {
							Get-EsxImageprofile "ESXi-5.1*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
						} else {
							if ($v50) {
								Get-EsxImageprofile "ESXi-5.0*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
							} else {
								# Workaround for http://kb.vmware.com/kb/2089217
								Get-EsxImageprofile "ESXi-5.0*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
								Get-EsxImageprofile "ESXi-5.1*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
								Get-EsxImageprofile "ESXi-5.5*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
								Get-EsxImageprofile "ESXi-6.0*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
								Get-EsxImageprofile "ESXi-6.5*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
								Get-EsxImageprofile "ESXi-6.7*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
								Get-EsxImageprofile "ESXi-7.0*" -Softwaredepot $basedepot | foreach { $iplist += $_ }
							}
						}
					}
				}
			}
		}
	}
}

if ($iplist.Length -eq 0) {
    write-host -F Red " [FAILED]`n`nFATAL ERROR: No valid Imageprofile(s) found!"
    if ($iZip) {
        write-host -F Red "The input file is probably not a full ESXi base bundle.`n"
    }
    exit
} else {
    write-host -F Green " [OK]"
    $iplist = @( $iplist | Sort-Object -Descending -Property @{Expression={$_.Name.Substring(0,10)}},@{Expression={$_.CreationTime.Date}},Name )
}

# if -sip then display menu of available image profiles ...
if ($sip) {
    if ($update) {
        write-host "`nSelect Imageprofile to use for update:"
    } else {
        write-host "`nSelect Base Imageprofile:"
    }
    write-host "-------------------------------------------"
    for ($i=0; $i -lt $iplist.Length; $i++ ) {
        write-host ($i+1): $iplist[$i].Name
    }
    write-host "-------------------------------------------"
    do {
        $sel = read-host "Enter selection"
        if (isNumeric $sel) {
            if (([int]$sel -lt 1) -or ([int]$sel -gt $iplist.Length)) { $sel = $null }
        } else {
            $sel = $null
        }
    } until ($sel)
    $idx = [int]$sel-1
} else {
    $idx = 0
}
if ($update) {
    $updIP = $iplist[$idx]
} else {
    $CloneIP = $iplist[$idx]
}

write-host ("`nUsing Imageprofile " + $CloneIP.Name + " ...")
write-host ("(Dated " + $CloneIP.CreationTime + ", AcceptanceLevel: " + $CloneIP.AcceptanceLevel + ",")
write-host ($CloneIP.Description + ")")

# If customization is required ...
if ( ($pkgDir -ne @()) -or $update -or ($load -ne @()) -or ($remove -ne @()) ) {

    # Create your own Imageprofile
    if ($ipname -eq "") { $ipname = $CloneIP.Name + "-customized" }
    if ($ipvendor -eq "") { $ipvendor = $CloneIP.Vendor }
    if ($ipdesc -eq "") { $ipdesc = $CloneIP.Description + " (customized)" }
    $MyProfile = New-EsxImageprofile -CloneProfile $CloneIP -Vendor $ipvendor -Name $ipname -Description $ipdesc

    # Update from Online depot profile
    if ($update) {
        write-host ("`nUpdating with the VMware Imageprofile " + $UpdIP.Name + " ...")
        write-host ("(Dated " + $UpdIP.CreationTime + ", AcceptanceLevel: " + $UpdIP.AcceptanceLevel + ",")
        write-host ($UpdIP.Description + ")")
        $diff = Compare-EsxImageprofile $MyProfile $UpdIP
        $diff.UpgradeFromRef | foreach {
            $uguid = $_
            $uvib = Get-EsxSoftwarePackage | where { $_.Guid -eq $uguid }
            write-host -nonewline "   Add VIB" $uvib.Name $uvib.Version
            AddVIB2Profile $uvib
        }
    }

    # Loop over Offline bundles and VIB files
    if ($pkgDir -ne @()) {
        write-host "`nLoading Offline bundles and VIB files from" $pkgDir ...
        foreach ($dir in $pkgDir) {
            foreach ($obundle in Get-Item $dir\*.zip) {
                write-host -nonewline "   Loading" $obundle ...
                if ($ob = Add-EsxSoftwaredepot $obundle -ErrorAction SilentlyContinue) {
                    write-host -F Green " [OK]"
                    $ob | Get-EsxSoftwarePackage | foreach {
                        write-host -nonewline "      Add VIB" $_.Name $_.Version
                        AddVIB2Profile $_
                    }
                } else {
                    write-host -F Red " [FAILED]`n      Probably not a valid Offline bundle, ignoring."
                }
            }
            foreach ($vibFile in Get-Item $dir\*.vib) {
                write-host -nonewline "   Loading" $vibFile ...
                try {
                    $vib1 = Get-EsxSoftwarePackage -PackageUrl $vibFile -ErrorAction SilentlyContinue
                    write-host -F Green " [OK]"
                    write-host -nonewline "      Add VIB" $vib1.Name $vib1.Version
                    AddVIB2Profile $vib1
                } catch {
                    write-host -F Red " [FAILED]`n      Probably not a valid VIB file, ignoring."
                }
            }
        }
    }
    # Load additional packages from Online depots or Offline bundles
    if ($load -ne @()) {
        write-host "`nLoad additional VIBs from Online depots ..."
        for ($i=0; $i -lt $load.Length; $i++ ) {
            if ($ovib = Get-ESXSoftwarePackage $load[$i] -Newest) {
                write-host -nonewline "   Add VIB" $ovib.Name $ovib.Version
                AddVIB2Profile $ovib
            } else {
                write-host -F Red "   [ERROR] Cannot find VIB named" $load[$i] "!"
            }
        }
    }
    # Remove selected VIBs
    if ($remove -ne @()) {
        write-host "`nRemove selected VIBs from Imageprofile ..."
        for ($i=0; $i -lt $remove.Length; $i++ ) {
            write-host -nonewline "      Remove VIB" $remove[$i]
            try {
                Remove-EsxSoftwarePackage -ImageProfile $MyProfile -SoftwarePackage $remove[$i] | Out-Null
                write-host -F Green " [OK]"
            } catch {
                write-host -F Red " [FAILED]`n      VIB does probably not exist or cannot be removed without breaking dependencies."
            }
        }
    }

} else {
    $MyProfile = $CloneIP
}


# Build the export command:
$cmd = "Export-EsxImageprofile -Imageprofile " + "`'" + $MyProfile.Name + "`'"

if ($ozip) {
    $outFile = "`'" + $outDir + "\" + $MyProfile.Name + ".zip" + "`'"
    $cmd = $cmd + " -ExportTobundle"
} else {
    $outFile = "`'" + $outDir + "\" + $MyProfile.Name + ".iso" + "`'"
    $cmd = $cmd + " -ExportToISO"
}
$cmd = $cmd + " -FilePath " + $outFile
if ($nsc) { $cmd = $cmd + " -NoSignatureCheck" }
$cmd = $cmd + " -Force"

# Run the export:
write-host -nonewline ("`nExporting the Imageprofile to " + $outFile + ". Please be patient ...")
if ($test) {
    write-host -F Yellow " [Skipped]"
} else {
    write-host "`n"
    Invoke-Expression $cmd
}

write-host -F Green "`nAll done.`n"

# The main catch ...
} catch {
    write-host -F Red ("`n`nAn unexpected error occurred:`n" + $Error[0])
    write-host -F Red ("`nIf requesting support please be sure to include the log file`n   " + $log + "`n`n")

# The main cleanup
} finally {
    cleanup
	if (!($PSBoundParameters.ContainsKey('log')) -and $PSBoundParameters.ContainsKey('outDir') -and ($outFile -like '*zip*')) {
		$finalLog = ($outDir + "\" + $MyProfile.Name + ".zip" + "-" + (get-date -Format yyyyMMddHHmm) + ".log")
		Move-Item $log $finalLog -force
		write-host ("(Log file moved to " + $finalLog + ")`n")
	} elseif (!($PSBoundParameters.ContainsKey('log')) -and $PSBoundParameters.ContainsKey('outDir') -and ($outFile -like '*iso*')) {
			$finalLog = ($outDir + "\" + $MyProfile.Name + ".iso" + "-" + (Get-Date -Format yyyyMMddHHmm) + ".log")
			Move-Item $log $finalLog -force
			write-host ("(Log file moved to " + $finalLog + ")`n")
		}
}
