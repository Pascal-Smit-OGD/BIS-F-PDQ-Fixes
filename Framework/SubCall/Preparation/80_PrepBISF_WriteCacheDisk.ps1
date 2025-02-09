﻿[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<#
	.SYNOPSIS
		Prepare PVSWriteCacheDisk
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
		Editor: Mike Bijl (Rewritten variable names and script format)
		Company:  EUCWeb.com

		History:
		28.02.2013 MS: Script created
		07.03.2013 MS: Read from diskpart, error to read substring, write empty uniqueID to registry
		25.06.2013 MS: Change location for temporary Diskpartfile to %TEMP%
		12.09.2013 MS: Critical fix to get uniqueid on english display language only
		18.09.2013 MS: replace $date with $(Get-date) to get current timestamp at running scriptlines write to the logfile
		01.10.2013 MS: add function SetRefSrv - Set Reference Server Hostname in registry to detect it in the personalize script to skip reboot
		03.03.2014 BR: Revisited Script
		18.03.2014 BR: revisited Script
		21.03.2014 MS: add setCDROM, last code change before release to web
		13.08.2014 MS: remove $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		13.08.2014 MS: Check if $returnCheckPVSSysVariable exists, then get uniqueID from persitend drive and set it to registry
		20.08.2014 MS: add line 70 -> get-LogContent -GetLogFile "$DiskpartFile"
		31.10.2014 MB: renamed variable: returnCheckPVSSysVariable -> returnTestPVSEnvVariable
		01.10.2015 MS: rewritten script to use central BISF function
		10.01.2017 MS: BugFix 134- PrepareWriteCacheDisk: add space on either side of the Driveletter variable $searvol, thx to Jeremy Saunders
		10.01.2017 MS: BugFix 134: PrepareWriteCacheDisk: MBR disk with 8 characters to get the right uniqueID from Diskpart only, PVS does not support GPT disk, see https://support.citrix.com/article/CTX139478 thx to Jeremy Saunders
		04.03.2017 MS: BugFix: DiskID is not language neutral, split string after ":" to read the right side only
		29.07.2017 MS: Feature Request 192: support GPT WriteCacheDisk
		25.08.2019 MS: ENH 128 - Disable any command if WriteCacheDisk is set to NONE
		05.10.2019 MS: HF 69 - If WriteCache disk on master is GPT-partiton then uniqueid doesn't match
		18.02.2020 JK: Fixed Log output spelling
		18.01.2021 MS: using PoSh standard verbs for functions

	.LINK
		https://eucweb.com
	#>

Begin {

	####################################################################
	# define environment
	# Setting default variables ($PSScriptroot/$logfile/$PSCommand,$PSScriptFullname/$scriptlibrary/LogFileName) independent on running script from console or ISE and the powershell version.
	If ($($host.name) -like "* ISE *") {
		# Running script from Windows Powershell ISE
		$PSScriptFullName = $psise.CurrentFile.FullPath.ToLower()
		$PSCommand = (Get-PSCallStack).InvocationInfo.MyCommand.Definition
	}
	ELSE {
		$PSScriptFullName = $MyInvocation.MyCommand.Definition.ToLower()
		$PSCommand = $MyInvocation.Line
	}
	[string]$PSScriptName = (Split-Path $PSScriptFullName -leaf).ToLower()
	If (($PSScriptRoot -eq "") -or ($PSScriptRoot -eq $null)) { [string]$PSScriptRoot = (Split-Path $PSScriptFullName).ToLower() }

	$SysDrive = $env:systemdrive
	$reg_value_UniqueID = "LIC_BISF_UniqueID_Disk"
	$reg_value_RefSrv_Hostname = "LIC_BISF_RefSrv_Hostname"
	$PVSDiskLabel = "PVSWriteCacheDisk"
	$DiskpartFile = "C:\Windows\Temp\$computer-DiskpartFile.txt"

	####################################################################
	####### functions #####
	####################################################################
	function Get-UniqueDiskID {
		<#
		.SYNOPSIS
		GetUniqueID

		.DESCRIPTION
		Write the UnqiueID of the CacheDisk to the registry
		to use it later on the cloned devices


		.NOTES
		Author: Matthias Schlimm

		Company:  EUCWeb.com

		History:
		dd.mm.yyyy MS: Script created
		18.01.2021 MS: HF 302 using function Get-BISFDiskID instead of the same code here

		#>
		Get-BISFDiskID -Driveletter $PVSDiskDrive -ThrowWhenNotFound $False
		Write-BISFLog -Msg "Set uniqueID $getid for volume $VolNbr / Driveletter $PVSDiskDrive to Registry $hklm_software_LIC_CTX_BISF_SCRIPTS"
		Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name $reg_value_UniqueID -value $DiskID -ErrorAction SilentlyContinue
	}

	function Set-ReferenceServer {
		# Set Reference Server Hostname in registry to detect it in the personalize script to skip reboot
		Write-BISFLog -Msg "Write Reference Server Hostname $computer to Registry $hklm_software_LIC_CTX_BISF_SCRIPTS"
		Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name $reg_value_RefSrv_Hostname -value $computer -ErrorAction SilentlyContinue
	}

	function Set-OpticalDrive {
		$CDrom = Get-CimInstance -ClassName Win32_Volume -Filter "DriveType = 5"
		$CDromDriveletter = $CDrom.Driveletter
		Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name "LIC_BISF_OptDrive" -Value $CDromDriveletter
		Write-BISFLog -Msg "set optical driveletter $CDromDriveletter"
	}

	####################################################################
	####### end functions #####
	####################################################################
}
Process {

	#### Main Program
	IF (!($LIC_BISF_CLI_WCD -eq "NONE")) {
		IF ($returnTestPVSEnvVariable -eq $true) {
			Get-UniqueDiskID
		}
		ELSE {
			Write-BISFLog -Msg "CacheDisk environment variable not defined, skipping configuration"
		}
	}
 ELSE {
		Write-BISFLog -Msg "CacheDisk is set to 'NONE', skipping configuration"
	}
	Set-OpticalDrive
	Set-ReferenceServer
}
END {
	Add-BISFFinishLine
}