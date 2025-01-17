Connect-AzAccount -Subscription 'Maersk Identity and Access Management Prod Tier 0 MN'


$ResourceGroupName = 'rgpazewpsoe9wiamjump9001'
$VMName = 'apsowiam4jbx01'
Get-AzVM -Name 'apsowiam4jbx01'



# Funkcja do pobrania informacji o karcie sieciowej
function Get-VMNetworkInterfaceDetails {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory=$true)]
        [string]$VMName
    )

    # Pobierz VM
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    
    # Pobierz wszystkie karty sieciowe podłączone do VM
    $nics = @()
    foreach ($nicId in $vm.NetworkProfile.NetworkInterfaces.Id) {
        $nic = Get-AzNetworkInterface -ResourceId $nicId
        $nics += $nic
    }

    # Szczegółowe informacje o każdej karcie sieciowej
    $nicDetails = @()
    foreach ($nic in $nics) {
        $nicInfo = [PSCustomObject]@{
            'Nazwa_NIC' = $nic.Name
            'Resource_Group' = $nic.ResourceGroupName
            'Location' = $nic.Location
            'Prywatny_IP' = $nic.IpConfigurations.PrivateIpAddress
            'Publiczny_IP' = if ($nic.IpConfigurations.PublicIpAddress) {
                (Get-AzPublicIpAddress -ResourceId $nic.IpConfigurations.PublicIpAddress.Id).IpAddress
            } else { "Brak" }
            'MAC_Address' = $nic.MacAddress
            'DNS_Servers' = if ($nic.DnsSettings.DnsServers) {
                $nic.DnsSettings.DnsServers -join ', '
            } else { "Domyślne" }
            'Enable_IP_Forwarding' = $nic.EnableIPForwarding
            'Enable_Accelerated_Networking' = $nic.EnableAcceleratedNetworking
        }
        $nicDetails += $nicInfo
    }

    return $nicDetails
}

# Funkcja do pobrania informacji o NSG
function Get-VMNetworkSecurityGroupDetails {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory=$true)]
        [string]$VMName
    )

    # Pobierz VM i jej karty sieciowe
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    $nsgDetails = @()

    foreach ($nicId in $vm.NetworkProfile.NetworkInterfaces.Id) {
        $nic = Get-AzNetworkInterface -ResourceId $nicId
        
        # Sprawdź NSG na poziomie karty sieciowej
        if ($nic.NetworkSecurityGroup) {
            $nsg = Get-AzNetworkSecurityGroup -ResourceId $nic.NetworkSecurityGroup.Id
            
            foreach ($rule in $nsg.SecurityRules) {
                $ruleInfo = [PSCustomObject]@{
                    'NSG_Name' = $nsg.Name
                    'Rule_Name' = $rule.Name
                    'Priority' = $rule.Priority
                    'Direction' = $rule.Direction
                    'Access' = $rule.Access
                    'Protocol' = $rule.Protocol
                    'Source_Port_Range' = $rule.SourcePortRange -join ', '
                    'Destination_Port_Range' = $rule.DestinationPortRange -join ', '
                    'Source_Address_Prefix' = $rule.SourceAddressPrefix -join ', '
                    'Destination_Address_Prefix' = $rule.DestinationAddressPrefix -join ', '
                }
                $nsgDetails += $ruleInfo
            }
        }
    }

    return $nsgDetails
}

# Funkcja do eksportu danych do CSV
function Export-NetworkInfo {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory=$true)]
        [string]$VMName,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    $nicDetails = Get-VMNetworkInterfaceDetails -ResourceGroupName $ResourceGroupName -VMName $VMName
    $nsgDetails = Get-VMNetworkSecurityGroupDetails -ResourceGroupName $ResourceGroupName -VMName $VMName

    # Eksport do CSV
    $nicDetails | Export-Csv -Path "$OutputPath\${VMName}_NIC_Details.csv" -NoTypeInformation -Encoding UTF8
    $nsgDetails | Export-Csv -Path "$OutputPath\${VMName}_NSG_Details.csv" -NoTypeInformation -Encoding UTF8
}

# Przykład użycia:
# Export-NetworkInfo -ResourceGroupName "twoja-grupa-zasobow" -VMName "nazwa-vm" -OutputPath "C:\Raporty"