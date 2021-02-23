[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,
	
	[Parameter(Mandatory=$true)]
    [string]$DomainNetBIOSName,
	
	[Parameter(Mandatory=$true)]
    [string]$wsfcName
)


$HostName = hostname
$AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
$ClusterAdminUser = $DomainNetBIOSName + '\' + $AdminUser.UserName
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))
$wsfcCN = $wsfcName
Invoke-Command -scriptblock { 
	$computer = get-adcomputer $Using:wsfcCN
	$discard,$OU = $computer -split ',',2
	$acl = get-acl "ad:$OU"
	$acl.access #to get access right of the OU
	$sid = [System.Security.Principal.SecurityIdentifier] $computer.SID
	$objectguid1 = new-object Guid bf967a86-0de6-11d0-a285-00aa003049e2 # is the rightsGuid for Create Computer Object class
	$inheritedobjectguid = new-object Guid bf967aa5-0de6-11d0-a285-00aa003049e2 # is the schemaIDGuid for the OU
	$identity = [System.Security.Principal.IdentityReference] $SID
	$adRights = [System.DirectoryServices.ActiveDirectoryRights] "CreateChild"
	$adRights2 = [System.DirectoryServices.ActiveDirectoryRights] "ReadProperty"
	$type = [System.Security.AccessControl.AccessControlType] "Allow"
	$inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
	$ace1 = new-object System.DirectoryServices.ActiveDirectoryAccessRule $identity,$adRights,$type,$objectGuid1,$inheritanceType,$inheritedobjectguid
	$ACE2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $identity,$adRights2,$type,$inheritanceType
	$acl.AddAccessRule($ace1)
	$acl.AddAccessRule($ACE2)
	Set-acl -aclobject $acl "ad:$OU" 
} -Credential $Credentials -ComputerName $HostName -Authentication credssp