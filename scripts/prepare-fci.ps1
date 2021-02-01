[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,
	
	[Parameter(Mandatory=$true)]
    [string]$DomainNetBIOSName,
	
	[Parameter(Mandatory=$true)]
    [string]$SqlUserSecret,
	
	[Parameter(Mandatory=$true)]
    [string]$MSSQLMediaBucket,
	
	[Parameter(Mandatory=$true)]
    [string]$MSSQLMediaKey

)

$HostName = hostname

# Creating Credential Object for Administrator
$AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
$ClusterAdminUser = $DomainNetBIOSName + '\' + $AdminUser.UserName
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))

#Retrieving MSSQL service account
$SqlUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $SqlUserSecret).SecretString
$SqlUserName = $DomainNetBIOSName + '\' + $SqlUser.UserName
$SqlUserPassword = $SqlUser.Password

#Acquiring MSSQL installation media from S3
$mediaIsoPath = 'c:\mssql-setup-media\en_sql_server_2019_developer_x64_dvd_baea4195.iso'
$mediaExtractPath = 'C:\SQLinstallmedia'

Copy-S3Object -BucketName $MSSQLMediaBucket -Key $MSSQLMediaKey -LocalFile $mediaIsoPath

#Mounting and extracting installation media files
New-Item -Path $mediaExtractPath -ItemType Directory
$mountResult = Mount-DiskImage -ImagePath $mediaIsoPath -PassThru
$volumeInfo = $mountResult | Get-Volume
$driveInfo = Get-PSDrive -Name $volumeInfo.DriveLetter
Copy-Item -Path ( Join-Path -Path $driveInfo.Root -ChildPath '*' ) -Destination $mediaExtractPath -Recurse
Dismount-DiskImage -ImagePath $mediaIsoPath

#Prepare FCI installation
$arguments = '/ACTION="PrepareFailoverCluster" /IAcceptSQLServerLicenseTerms="True" /IACCEPTROPENLICENSETERMS="False" /SUPPRESSPRIVACYSTATEMENTNOTICE="True" /ENU="True" /QUIET="True" /UpdateEnabled="False" /USEMICROSOFTUPDATE="False" /SUPPRESSPAIDEDITIONNOTICE="True" /UpdateSource="MU" /FEATURES=SQLENGINE,REPLICATION,FULLTEXT,DQ /HELP="False" /INDICATEPROGRESS="False" /X86="False" /INSTANCENAME="MSSQLSERVER" /INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server" /INSTANCEID="MSSQLSERVER" /INSTANCEDIR="C:\Program Files\Microsoft SQL Server" /AGTSVCACCOUNT="{0}" /AGTSVCPASSWORD="{1}" /FILESTREAMLEVEL="0" /SQLSVCACCOUNT="{0}" /SQLSVCPASSWORD="{1}" /SQLSVCINSTANTFILEINIT="False" /FTSVCACCOUNT="NT Service\MSSQLFDLauncher"' -f $SqlUserName, $SqlUserPassword
Invoke-Command -scriptblock { 
    Start-Process -FilePath C:\SQLinstallmedia\setup.exe -ArgumentList $Using:arguments -Wait -NoNewWindow
} -Credential $Credentials -ComputerName $HostName -Authentication credssp