FROM vmware/powerclicore:latest

# Add ESXi-Customizer-PS.ps1
ADD https://raw.githubusercontent.com/VFrontDe/ESXi-Customizer-PS/master/ESXi-Customizer-PS.ps1 /usr/local/bin/ESXi-Customizer-PS.ps1

ENTRYPOINT [ "/usr/bin/pwsh", "/usr/local/bin/ESXi-Customizer-PS.ps1", "-outDir", "/data" ]

VOLUME [ "/data" ]
