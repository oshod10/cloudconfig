<#
Before running this file, make sure that you have the AZ module on your system installed. If not, then run the following PS command from the Powershell.
Install-Module -Name Az -AllowClobber -Scope AllUsers

To execute the script do the following:

1 - Copy the PS file to your favorite location on the computer
2 - Change the path to that location and run the below command
    PS C:\Downloads> .\localdeploy_capita.ps1 -Environment lab -PostFix 01 -Identifier 01 -Region EUN -zone i REDUCED
3 - Environment, Postfix, Identifier, Region, Zone, Scale are the mandatory inputs. Change their values according to your needs.

Azure list of regions for cmdlet 
uksouth, ukwest, northeurope, westeurope
#>

[CmdletBinding()]

Param(
   [Parameter(Mandatory = $true)]
   [ValidateSet("pp", "prod", "dev", "mgmt", "train","lab", "dr")]
   $Environment,
   [Parameter(Mandatory = $true)]
   [string]
   $PostFix,
   [Parameter(mandatory = $true)]
   [string]
   $Identifier,
   [parameter(mandatory = $true)]
   [validateset("UKS", "UKW", "EUN", "EUW")]
   $Region,
   [parameter(mandatory = $true)]
   [validateset( "m", "c", "i", "n", "p")]
   $Zone,
   [parameter(mandatory = $true)]
   [validateset( "FULL", "REDUCED")]
   $Scale
   
)

$storageTier = "hot"
$Version = "9.0"


$Region = $Region.ToLower()
if(($Environment -ne "pp") -And ( $Environment -ne "dr"))
{
$Environment = $Environment.ToLower()
$env = $Environment.Substring(0,1)
}
elseif ($Environment -eq "pp") {
$env = "z"
}
elseif ($Environment -eq "dr") {
$env = "x"
}

if ($Region -eq "EUN")
{ $location = "northeurope"}
elseif ($Region -eq "EUW")
{$location = "westeurope"}
elseif ($Region -eq "UKS")
{$location = "uksouth"}
elseif ($Region -eq "UKW")
{$location = "ukwest"}


$resourceGroupName = "rgam"+ $Identifier + $env + $PostFix + $Region
write-host "Resource Group Name: $resourceGroupName " -ForegroundColor yellow
$deploymentName="Optima-Deployment-$(get-random -Maximum 999)"
write-host "deployment Name $deploymentName" -ForegroundColor yellow
$StorageResourceGroupName = $resourceGroupName
$StorageAccountName = "st" + $Identifier + $storageTier.Substring(0,1) + $env + $PostFix
write-host "Storage Name $StorageAccountName" -ForegroundColor yellow
$StorageContainerName = "templates"




if ($Environment -ne "dr")
{
if ($Scale -eq "FULL")
{$templatefile = "https://acccapita.blob.core.windows.net/$StorageContainerName/Releases/$Version/FULLSCALE/azuredeploy.json"}
elseif ($Scale -eq "REDUCED")
{$templatefile = "https://acccapita.blob.core.windows.net/$StorageContainerName/Releases/$Version/REDUCEDSCALE/azuredeploy.json"}
}
else {$templatefile = "https://acccapita.blob.core.windows.net/$StorageContainerName/Releases/$Version/DR/azuredeploy.json"}


# Validate Azure context
$context = Get-AzContext
if (!$context) { Connect-azAccount ; $context = Get-AzContext }
$User = $context.account.id
write-host "Current user is $User" -ForegroundColor yellow



# Suggest user replacement
Do {
   $ReplaceUser = Read-Host "Would you like to replace user? [Yes \ No]"
   if ($ReplaceUser -eq "yes") { Connect-azAccount }
   elseif ($ReplaceUser -eq "No") { }
   else { Write-Warning "Please enter 'Yes' or 'No'" }   
   }
Until ($ReplaceUser -eq "Yes" -or $ReplaceUser -eq "No")





#Validate Resource Group and create if not exists already 
if (!(Get-azResourceGroup -Name $resourceGroupName -ErrorAction Ignore)) 
  { New-azResourceGroup -Name $resourceGroupName -Location $location 
   write-host "Resource group $resourceGroupName created sucessfully!" -ForegroundColor yellow
      } 




#Validate Storage account and create if not exists already 
if (!(Get-azStorageAccount -Name $StorageAccountName -ResourceGroupName $resourceGroupName -ErrorAction Ignore))
{
New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $StorageAccountName -Location $location -SkuName Standard_LRS -Kind StorageV2 -AccessTier $storageTier
write-host "Storage $StorageAccountName created sucessfully!" -ForegroundColor yellow
  }
else {Write-Host "Storage account exists already, skipping step!" -ForegroundColor yellow}
$StorageAccount = (Get-azStorageAccount -ResourceGroupName sourcecontrolrg | Where-Object { $_.StorageAccountName -eq "acccapita" })



# Create SAS token 
$sasToken = (New-AzStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission rwdl -ExpiryTime (Get-Date).AddHours(4))


# Full template path with sas token
$templatefileUri = $templatefile + $sasToken


#Invoke json deployment files

    New-azResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName `
      -TemplateUri $templatefileUri `
      -templateSastoken $sasToken -environment $env -envpostfix $PostFix -env $Environment -user $user -identifier $Identifier -region $Region -zone $Zone -storagetier $storageTier.Substring(0,1) -Verbose
      
