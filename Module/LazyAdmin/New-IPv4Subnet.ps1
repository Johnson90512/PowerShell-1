﻿###############################################################################################################
# Language     :  PowerShell 4.0
# Filename     :  New-IPv4Subnet.ps1
# Autor        :  BornToBeRoot (https://github.com/BornToBeRoot)
# Description  :  Calculate a subnet based on an IP-Address and the subnetmask or CIDR
# Repository   :  https://github.com/BornToBeRoot/PowerShell
###############################################################################################################

<#
    .SYNOPSIS
    Calculate a subnet based on an IP-Address and the subnetmask or CIDR

    .DESCRIPTION
    Calculate a subnet based on an IP-Address within the subnet and the subnetmask or CIDR.
    The result includes the NetworkID, Broadcast, total available IPs and usable IPs for hosts.
                
    .EXAMPLE
    New-IPv4Subnet -IPv4Address 192.168.24.96 -CIDR 27
    
    NetworkID     Broadcast      IPs Hosts
    ---------     ---------      --- -----
    192.168.24.96 192.168.24.127  32    30
            
    .EXAMPLE
    New-IPv4Subnet -IPv4Address 192.168.1.0 -Mask 255.255.255.0

    NetworkID   Broadcast     IPs Hosts
    ---------   ---------     --- -----
    192.168.1.0 192.168.1.255 256   254

    .LINK
    https://github.com/BornToBeRoot/PowerShell/blob/master/Documentation/New-IPv4Subnet.README.md
#>

function New-IPv4Subnet
{
    [CmdletBinding(DefaultParameterSetName='CIDR')]
    param(
        [Parameter(
            Position=0,
            Mandatory=$true,
            HelpMessage='IPv4-Address which is in the subnet')]
        [IPAddress]$IPv4Address,

        [Parameter(
            ParameterSetName='CIDR',
            Position=1,
            Mandatory=$true,
            HelpMessage='CIDR like /24 without "/"')]
        [ValidateRange(0,32)]
        [Int32]$CIDR,

        [Parameter(
            ParameterSetName='Mask',
            Position=1,
            Mandatory=$true,
            Helpmessage='Subnetmask like 255.255.255.0')]
        [IPAddress]$Mask
    )

    Begin{
      
    }

    Process{
        # Convert Mask or CDIR - because we need both in the code below
        switch($PSCmdlet.ParameterSetName)
        {
            "CIDR" {                          
                # Make a string of bits (24 to 11111111111111111111111100000000)
                $CIDR_Bits = ('1' * $CIDR).PadRight(32, "0")

                # Split into groups of 8 bits, convert to Ints, join up into a string
                $Octets = $CIDR_Bits -split '(.{8})' -ne ''
                $Mask = ($Octets | foreach { [System.Convert]::ToInt32($_, 2) }) -join '.'
            }

            "Mask" {
                # Convert the numbers into 8 bit blocks, join them all together, count the 1
                $Octets = $Mask.ToString().Split('.') | foreach {[System.Convert]::ToString($_, 2)}
                $CIDR_Bits = ($Octets -join "").TrimEnd("0")

                # /16 -> 1111111111111111 (if there is a 0 inside... it`s not valid)
                if([char[]]$CIDR_Bits -contains "0")
                {
                    Write-Host "$Mask is not a valid subnetmask" -ForegroundColor Yellow
                    return 
                }
                else
                {
                    $CIDR = $CIDR_Bits.Length 
                }
            }              
        }
        
        # Get CIDR Address by parsing it into an IP-Address
        $CIDRAddress = [System.Net.IPAddress]::Parse([System.Convert]::ToUInt64(("1"* $CIDR).PadRight(32, "0"), 2))
    
        # Binary AND ... this is how subnets work.
        $NetworkID_bAND = $IPv4Address.Address -band $CIDRAddress.Address

        # Return an array of bytes. Then join them.
        $NetworkID = [System.Net.IPAddress]::Parse([System.BitConverter]::GetBytes([UInt32]$NetworkID_bAND) -join ("."))
        
        # Get HostBits based on SubnetBits (CDIR) // Hostbits (32 - /24 = 8 -> 00000000000000000000000011111111)
        $HostBits = ('1' * (32 - $CIDR)).PadLeft(32, "0")
        
        # Convert Bits to Int64
        $AvailableIPs = [Convert]::ToInt64($HostBits,2)

        # Convert Network Address to Int64
        $NetworkID_Int64 = (Convert-IPv4Address -IPv4Address $NetworkID.ToString()).Int64

        # Convert add available IPs and parse into IPAddress
        $Broadcast = [System.Net.IPAddress]::Parse((Convert-IPv4Address -Int64 ($NetworkID_Int64 + $AvailableIPs)).IPv4Address)
        
        # Change useroutput ==> (/27 = 0..31 IPs -> AvailableIPs 32)
        $AvailableIPs += 1

        # Hosts = AvailableIPs - Network Address + Broadcast Address
        $Hosts = ($AvailableIPs - 2)
            
        # Build custom PSObject
        $Result = New-Object -TypeName PSObject
        Add-Member -InputObject $Result -MemberType NoteProperty -Name NetworkID -Value $NetworkID
        Add-Member -InputObject $Result -MemberType NoteProperty -Name Broadcast -Value $Broadcast
        Add-Member -InPutObject $Result -MemberType NoteProperty -Name IPs -Value $AvailableIPs
        Add-Member -InPutObject $Result -MemberType NoteProperty -Name Hosts -Value $Hosts
        return $Result
    }

    End{

    }
}
