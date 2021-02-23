[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$DomainNetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,

    [Parameter(Mandatory=$false)]
    [string]$FSxRemoteAdminEndpoint

)


$AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
$ClusterAdminUser = $DomainNetBIOSName + '\' + $AdminUser.UserName
# Creating Credential Object for Administrator
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))

#Configure CA SMB share on FSx
$shareName = "SqlShare"
Invoke-Command -ComputerName $FSxRemoteAdminEndpoint -ConfigurationName FSxRemoteAdmin -scriptblock {   
  New-FSxSmbShare -Name $Using:shareName -Path "D:\share\" -Description "CA share for MSSQL FCI" -ContinuouslyAvailable $True -Credential $Using:Credentials 
} -Credential $Credentials

Invoke-Command -ComputerName $FSxRemoteAdminEndpoint -ConfigurationName FSxRemoteAdmin -scriptblock {   
  Grant-FSxSmbShareAccess -Name $Using:shareName -AccountName $Using:ClusterAdminUser -AccessRight Full -force
} -Credential $Credentials

#Configure Witness SMB share on FSx
$WitnessshareName = "SqlWitnessShare"
Invoke-Command -ComputerName $FSxRemoteAdminEndpoint -ConfigurationName FSxRemoteAdmin -scriptblock {   
  New-FSxSmbShare -Name $Using:WitnessshareName -Path "D:\share\" -Description "Witness share for MSSQL FCI" -ContinuouslyAvailable $True -Credential $Using:Credentials 
} -Credential $Credentials

Invoke-Command -ComputerName $FSxRemoteAdminEndpoint -ConfigurationName FSxRemoteAdmin -scriptblock {   
  Grant-FSxSmbShareAccess -Name $Using:WitnessshareName  -AccountName Everyone -AccessRight Change -force 
} -Credential $Credentials





