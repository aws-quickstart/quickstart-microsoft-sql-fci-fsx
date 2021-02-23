[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$DomainNetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]$DomainDnsName,

    [Parameter(Mandatory=$true)]
    [string]$WSFCNode1PrivateIP2,

    [Parameter(Mandatory=$true)]
    [string]$ClusterName,

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,

    [Parameter(Mandatory=$false)]
    [string]$FileServerNetBIOSName

)

# Getting the DSC Cert Encryption Thumbprint to Secure the MOF File
$DscCertThumbprint = (get-childitem -path cert:\LocalMachine\My | where { $_.subject -eq "CN=AWSQSDscEncryptCert" }).Thumbprint
# Getting Password from Secrets Manager for AD Admin User
$AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
$ClusterAdminUser = $DomainNetBIOSName + '\' + $AdminUser.UserName
# Creating Credential Object for Administrator
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))

if ($FileServerNetBIOSName) {
    $ShareName = "\\" + $FileServerNetBIOSName + "\SqlWitnessShare"
}

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName="*"
            CertificateFile = "C:\AWSQuickstart\publickeys\AWSQSDscPublicKey.cer"
            Thumbprint = $DscCertThumbprint
            PSDscAllowDomainUser = $true
        },
        @{
            NodeName = 'localhost'
        }
    )
}

Configuration WSFCNode1Config {
    param(
        [PSCredential] $Credentials
    )

    Import-Module -Name PSDscResources
    Import-Module -Name xFailOverCluster
    Import-Module -Name xActiveDirectory
    
    Import-DscResource -Module PSDscResources
    Import-DscResource -ModuleName xFailOverCluster
    Import-DscResource -ModuleName xActiveDirectory
    
    Node 'localhost' {
        WindowsFeature RSAT-AD-PowerShell {
            Name = 'RSAT-AD-PowerShell'
            Ensure = 'Present'
        }

        WindowsFeature AddFailoverFeature {
            Ensure = 'Present'
            Name   = 'Failover-clustering'
            DependsOn = '[WindowsFeature]RSAT-AD-PowerShell' 
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-Mgmt'
            DependsOn = '[WindowsFeature]AddFailoverFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringPowerShellFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-PowerShell'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-CmdInterface'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
        }

        xCluster CreateCluster {
            Name                          =  $ClusterName
            StaticIPAddress               =  $WSFCNode1PrivateIP2
            DomainAdministratorCredential =  $Credentials
            DependsOn                     = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature' 
        }

        if ($FileServerNetBIOSName) {
            xClusterQuorum 'SetQuorumToNodeAndFileShareMajority' {
                IsSingleInstance = 'Yes'
                Type             = 'NodeAndFileShareMajority'
                Resource         = $ShareName
                DependsOn        = '[xCluster]CreateCluster'
            }
        } else {
            xClusterQuorum 'SetQuorumToNodeMajority' {
                IsSingleInstance = 'Yes'
                Type             = 'NodeMajority'
                DependsOn        = '[xCluster]CreateCluster'
            }
        }
    }
}
    
WSFCNode1Config -OutputPath 'C:\AWSQuickstart\WSFCNode1Config' -ConfigurationData $ConfigurationData -Credentials $Credentials
