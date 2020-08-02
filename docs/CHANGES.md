### === Change History ===

######  Version 2.8.1 (2020-05-17)
	(Vladislav) Enhanced `-pkgDir` switch to support a list of local directories

######  Version 2.8.0 (2020-04-02)
	(Alex) Made the script fully compatible with vSphere 7.0

######  Version 2.7.0 (2018-05-25)
	(Alex) Enhanced variable for better VMware.PowerCLI module version detection; script restructure
	(Andre) Added -pzip parameter to use an Offline patch bundle instead of the Online depot with -update

###### Version 2.6.0 (2018-04-18)
	Made the script fully compatible with vSphere 6.7 and PowerCLI 10

###### Version 2.5.1 (2017-09-07)
	Removed expired electronic signature
	Removed code to resize the console screen (caused too many issues)

###### Version 2.5 (2016-11-23)
	Made the script fully compatible with vSphere 6.5 and PowerCLI 6.5
	Enhanced script log file naming

###### Version 2.4.3 (2015-09-11)
	Updated electronic signature

###### Version 2.4.2 (2015-06-02)
	Fixed an issue with -izip -update, and the Input bundle containing multiple Imageprofiles: The script will now pick the latest standard profile from the list and update that.

###### Version 2.4.1 (2015-04-29)
	Fixed a small issue with the script not launching from a pure Powershell, but only from a PowerCLI session (Yikes!)

###### Version 2.4 (2015-04-24)
	Fixed launch of the script from a PowerCLI 6.0 console
	Updated help screen and Online doc for ESXi 6.0
	Added new switch -remove

###### Version 2.3 (2014-10-01)
	Implemented workaround for the problem described in KB2089217
	Added ability to add VIB files
	Improved error handling and logging
	Removed HP specific features (-hp and -hprel)

###### Version 2.2 (2014-02-12)
	Fixed the -update -izip logic to correctly update only existing packages
	Reverted the change to the add VIB logic introduced in 2.1

###### Version 2.1 (2014-02-11)
	Fixed the add VIB logic to never downgrade a package
	Added -load switch to add additional VIBs from any connected Online Depot
	Added -vft switch to connect the V-Front Online Depot
	Added -dpt switch to connect additional Online Depots by URL
	Added -v55 switch to limit image profile selection to ESXi 5.5

###### Version 2.0 (2013-11-23)
	Added -update switch to update a local ESXi Offline bundle with an ESXi patch from the VMware Online Depot
	Added -v51 switch to limit the focus to ESXi 5.1 (and ignore newer releases)
	Added -ipdesc option to set custom ImageProfile description
	Added -ipvendor option to set custom ImageProfile vendor
	Added console window re-sizing and coloring

###### Version 1.4.3 (2012-10-01)
	Fixed ImageProfile sorting and detection of recent release

###### Version 1.4.2 (2012-09-28)
	Added -force switch when adding packages (to prevent dependency checks)

###### Version 1.4.1 (2012-09-27)
	Added PowerCLI version check and compatibility to PowerCLI 5.1

###### Version 1.4 (2012-09-17)
	Added -v50 to limit the focus to ESXi 5.0 (and ignore newer releases)
	Added -ozip option to create an Offline Bundle instead of an ISO file
	Renamed -isoDir parameter to -outDir
	Added logic to export only the orig. VMware profile if -obDir and -hp are both not specified
	Added -nsc (-NoSignatureCheck) parameter for ISO export
	Added -izip option to use an ESXi Offline bundle (instead of the Online depot) for input
	Added electronic signature to script

###### Version 1.2 (2012-06-27)
	Added manual selection of ImageProfile to clone (-sip), naming of custom profile (-ipname) and HP Depot release selection (-hprel). Added cleanup at end of script.

###### Version 1.1 (2012-06-07)
	Fixed HP Online depot handling
	Introduced -test parameter to skip download and build

###### Version 1.0 (2012-05-31)
	Initial version
