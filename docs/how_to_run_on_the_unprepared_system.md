There is a some commands that you need to run before that script can made what it does.

##Windows 10 (and most other)

###1
Open powershell as administrator and paste:
`Set-ExecutionPolicy Unrestricted`
 more about that command you can read at https:/go.microsoft.com/fwlink/?LinkID=135170

###2 Additional modules
If you run the script now - you will get an error like:
error : `FATAL ERROR: VMware.VimAutomation.Core is not available as a module or snap-in! It looks like there is no compatible version of PowerCLI installed!`
that error means you need to install additional modules, to do that:

`Install-Module -Name VMware.VimAutomation.Core`
`Install-Module -Name VMware.ImageBuilder`
`Install-Module -Name VMware.PowerCLI`


###3 Run the script
and get the result

 
