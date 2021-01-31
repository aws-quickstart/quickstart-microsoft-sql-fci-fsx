[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$DomainDNSName
	
)	


$HostName = hostname
$HostAddress = "{0}.{1}" -f $HostName, $DomainDNSName
Enable-WSManCredSSP -Role "Server" -Force
Enable-WSManCredSSP -Role "Client" -DelegateComputer $HostAddress -Force