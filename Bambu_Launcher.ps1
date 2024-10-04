<#
.SYNOPSIS
Launches Bambu Studio and spoofs the printer broadcast to the local Bambu Studio listening port (UDP/2021).

.DESCRIPTION
BambuLab printers send an SSDP broadcast to UDP/2021 so the Bambu Studio app can discover
the printer over the network. This requires both the printer and the client to be on the
same network segment. In order to put the printer(s) on a separate vLAN and allow the client to access
the printer(s) from other vLAN segments, a spoofed broadcast is sent to the local listening port with
information about known printers.

UDP/2021 must be opened on the local computer firewall.

.NOTES
Original Bash script Author: gashton https://github.com/gashton

PowerShell port by withanhdammit https://github.com/withanhdammit
October 2024
#>

# Function to send UDP datagrams to a fixed IP and port (localhost:2021)
Function Send-UDPDatagram {
    Param (
        [string] $packet
    )
    
    $endPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse("127.0.0.1"), 2021)
    $socket = New-Object System.Net.Sockets.UdpClient
    $encodedText = [Text.Encoding]::ASCII.GetBytes($packet)
    
    # Send the UDP broadcast
    $socket.Send($encodedText, $encodedText.Length, $endPoint) | Out-Null
    $socket.Close()
}

# Model reference
# Printer | Use
# ------- | -------------------
# A1      | N2S
# A1 Mini | N1
# P1P     | C11
# P1S     | C12
# X1      | 3DPrinter-X1
# X1C     | 3DPrinter-X1-Carbon
# X1E     | C13

# One PSCustomObject block per printer.  If only one, drop the trailing ','
$printers = @(
    [PSCustomObject]@{
        IP = "1.2.3.4"  # Printer 1 IP
        USN = "01P00A123456789"  # Printer 1 Serial Number
        DevModel = "C12"  # Printer 1 = P1S
        DevName = "bam"  # Printer 1 Device Name
    },
    [PSCustomObject]@{
        IP = "1.2.3.5"  # Printer 2 IP
        USN = "01P00A987654321"  # Printer 2 Serial Number
        DevModel = "C12"  # Printer 2 = P1S
        DevName = "boo"  # Printer 2 Device Name
    }
)

# Check if BambuStudio is running, and if not, launch it
If (-not (Get-Process bambu-studio -ErrorAction SilentlyContinue)) {
    Write-Host "Launching Bambu Studio, please wait..."
    Start-Process "C:\Program Files\Bambu Studio\bambu-studio.exe" # Update this with the actual path to Bambu Studio on your system
    
    # Wait for a few seconds to allow BambuStudio to initialize
    Start-Sleep -Seconds 30
}

# Loop through each printer and send the response
ForEach ($printer in $printers) {

    # Prepare the datagram
    $datagram = @"
HTTP/1.1 200 OK
Server: Buildroot/2018.02-rc3 UPnP/1.0 ssdpd/1.8
Date: $(Get-Date)
Location: $($printer.IP)
ST: urn:bambulab-com:device:3dprinter:1
EXT:
USN: $($printer.USN)
Cache-Control: max-age=1800
DevModel.bambu.com: $($printer.DevModel)
DevName.bambu.com: $($printer.DevName)
DevSignal.bambu.com: -44
DevConnect.bambu.com: lan
DevBind.bambu.com: free

"@
    Send-UDPDatagram -Packet $datagram
    Write-Host "Activated BambuLab printer $($printer.DevName)"
    Start-Sleep -Seconds 1
}
