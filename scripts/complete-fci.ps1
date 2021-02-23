    [CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,
	
    [Parameter(Mandatory=$true)]
    [string]$DomainNetBIOSName,
	
	[Parameter(Mandatory=$true)]
    [string]$FileServerPath,
	
	[Parameter(Mandatory=$true)]
    [string]$Node1FciIp,

    [Parameter(Mandatory=$true)]
    [string]$Node1SubnetMask,
    
	[Parameter(Mandatory=$true)]
    [string]$Node2FciIp,

    [Parameter(Mandatory=$true)]
    [string]$Node2SubnetMask,
	
	[Parameter(Mandatory=$true)]
    [string]$FCIName,
	
	[Parameter(Mandatory=$true)]
    [string]$SQLAdminAccounts

)

# Creating Credential Object for Administrator
$AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
$ClusterAdminUser = $DomainNetBIOSName + '\' + $AdminUser.UserName
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))

#https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt?view=sql-server-ver15

$HostName = hostname

#Need to run cluster validation first
Invoke-Command -scriptblock { Test-Cluster } -Credential $Credentials -ComputerName $HostName -Authentication credssp

$mediaExtractPath = 'C:\SQLinstallmedia'
$sqlRootPath = "\\{0}\SqlShare\mssql" -f $FileServerPath
$sqlDataPath = "\\{0}\SqlShare\mssql\data" -f $FileServerPath
$sqlLogPath = "\\{0}\SqlShare\mssql\logs" -f $FileServerPath

 
$arguments = '/QUIET /ACTION=CompleteFailoverCluster /InstanceName=MSSQLSERVER /INDICATEPROGRESS=FALSE /FAILOVERCLUSTERNETWORKNAME={0} /FAILOVERCLUSTERIPADDRESSES="IPv4;{1};Cluster Network 1;{2}" "IPv4;{3};Cluster Network 2;{4}" /CONFIRMIPDEPENDENCYCHANGE=TRUE /FAILOVERCLUSTERGROUP="SQL Server (MSSQLSERVER)" /INSTALLSQLDATADIR="C:\Program Files\Microsoft SQL Server" /SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS" /SQLSYSADMINACCOUNTS={5} /INSTALLSQLDATADIR={6} /SQLUSERDBDIR={7} /SQLUSERDBLOGDIR={8}' -f $FCIName, $Node1FciIp, $Node1SubnetMask, $Node2FciIp, $Node2SubnetMask, $SQLAdminAccounts, $sqlRootPath, $sqlDataPath, $sqlLogPath 
Invoke-Command -scriptblock { 
    Start-Process -FilePath C:\SQLinstallmedia\setup.exe -ArgumentList $Using:arguments -Wait -NoNewWindow
} -Credential $Credentials -ComputerName $HostName -Authentication credssp
