#How to run

# .\PrivateDnsZone.ps1 -zoneName capitapp2.com -rgName rgam01z02eun -vnetName vn01z02eun -storageAccName st01hz02


[CmdletBinding()]

Param(
   [Parameter(Mandatory = $true)]
   [String]
   $zoneName,
   [Parameter(Mandatory = $true)]
   [String]
   $rgName,
   [Parameter(Mandatory = $true)]
   [String]
   $vnetName,
   [Parameter(Mandatory = $true)]
   [String]
   $storageAccName
   )
   
$Array = $zoneName.Split(".")
$link=$Array[0] + "link"

$Vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName

Write-Host -ForegroundColor Green "Creating a Private DNS Zone.."  
New-AzPrivateDnsZone -Name $zoneName -ResourceGroupName $rgName
New-AzPrivateDnsVirtualNetworkLink -ZoneName $zoneName -ResourceGroupName $rgName -Name $link -VirtualNetworkId $Vnet.Id -EnableRegistration 


## Create a file share  

$dataFS="data"
$ftpFS="ftp"
 
Write-Host -ForegroundColor Green "Creating a file Share.."    
#Get the storage account context  
$ctx=(Get-AzStorageAccount -ResourceGroupName $rgName -Name $storageAccName).Context  
New-AzStorageShare -Context $ctx -Name $dataFS 
New-AzStorageShare -Context $ctx -Name $ftpFS
