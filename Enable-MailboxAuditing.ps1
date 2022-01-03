<# 
.SYNOPSIS
This script automates the enabling of the default audit value on mailboxes in Exchange Online. 

.DESCRIPTION
 This has been created because sadly even when enabling default auditing for your tenant this 
 does not apply for all mailboxes and does not send this information to the Unified Messaging Log. 
 
 Unless you have assigned a E5 License to the mailbox.  

## Enable-MailboxAuditing.ps1 [-EnableMailboxLoginAudit <Boolean>] [-DifferentialScope <Int>] [-AutomationPSCredential <String>] 
[-WhatIf <Switch>] [-EXOOrganization <string[*.onmicrosoft.com]>] [-EXOAutomationPSConnection <string[Name]>]

.PARAMETER EnableMailboxLoginAudit
 The EnableMailboxLoginAudit parameter adds to the audit log MailboxLogin for the AuditOwner. 
 The default audit logging flag does not track owner login events. This can be enabled manually
 and is recommended for most enviroments unless there are other constraints.     

.PARAMETER WhatIf
 The WhatIf switch simulates the actions of the command. You can use this switch to view the 
 changes that would occur without actually applying those changes. You don't need to specify 
 a value with this switch.

.PARAMETER DifferentialScope
 The DifferentialScope parameter defines how many objects can be added or removed from the 
 UserGroups in a single operation of the script. The goal of this setting is throttle bulk
 changes to limit the impact of misconfiguration by an administrator. 
 
 What value you choose here will be dictated by your requirements. 
 
 The default value is set to 100 Objects. 

.PARAMETER AutomationPSCredential
 The AutomationPSCredential parameter defines which Azure Automation Cred you would like to use. 

 This account must have the access to Read | Write to Mailbox Users. 

 .PARAMETER EXOOrganization
The CertificateOrganization parameter identifies the tenant Microsoft address. For example 
'consto.onmicrosoft.com' Parameter must be used with -EXOAutomationPSCertificate & -EXOAutomationPSConnection. 

.PARAMETER EXOAutomationPSConnection
 The AutomationPSConnection parameter defines the connection details such as AppID, Tenant ID. 
 Parameter must be used with -EXOAutomationPSCertificate & -EXOOrganization. 
    In your Azure Automation Account:
        1. Connections
        2. Add a Connection 
        3. Select AzureServicePrincipal
        4. Fill in require fields 

.EXAMPLE
 Enable-MailboxAuditing.ps1 -EnableMailboxLoginAudit:$true -WhatIf 

 -- REPORT ONLY --

 In this example the script will make no changes to the mailbox instead testing enabling for all mailboxes.
 Once you are happy with the result remove the mailbox -WhatIf switch to apply the real settings. 

.EXAMPLE
 Enable-MailboxAuditing.ps1 -EnableMailboxLoginAudit:$true -EXOOrganization contso.onmicrosoft.com -EXOAutomationPSConnection "ExchangeOnlineApp"

 -- APP ONLY IN AZURE AUTOMATION --

 In this example the script will enable all mailboxes with auditing including the switch to log the last logon user to the mailbox. 

.LINK

Manage mailbox auditing - https://docs.microsoft.com/en-us/microsoft-365/compliance/enable-mailbox-auditing?view=o365-worldwide#more-information

 Although mailbox audit logging on by default is enabled for all organizations, only users with E5 licenses 
 will return mailbox audit log events in audit log searches in the Security & Compliance Center or via the 
 Office 365 Management Activity API by default.

 Supported Types - https://docs.microsoft.com/en-us/microsoft-365/compliance/enable-mailbox-auditing?view=o365-worldwide#supported-mailbox-types

 Resource Mailboxes Public Folder Mailboxes not not supported by the default audit logging and must be manually enabled. 

.NOTES

[AUTHOR]
Joshua Bines, Consultant

Find me on:
* Web:     https://theinformationstore.com.au
* LinkedIn:  https://www.linkedin.com/in/joshua-bines-4451534
* Github:    https://github.com/jbines
  
[VERSION HISTORY / UPDATES]
1.0.0 20190221 - Cam Murray - https://github.com/o365soa/Scripts/commit/5c97b3387103db16bc5ef323a8de03fdb224502a#diff-6803b320d86c059402fc2b7b43b68e64
1.0.1 20190221 - Scott Bueffel - https://github.com/o365soa/Scripts/blob/master/Configure-MailboxAuditing.ps1
1.0.2 20200811 - JBINES - [FEATURE] Added AzureAutomation Support, changed the mailbox filter and a few UI changes just for kicks. 
1.0.3 20200811 - JBINES - [FEATURE] Added support for logining 'MailboxLogin' which is not enabled by default.
1.0.4 20220104 - JBINES - [FEATURE] Added support for module EXO v2 & Modern App Only runtime access.


[TO DO LIST / PRIORITY]
HIGH - Misses E5 Mailboxes Auditing MailboxLogin
MED - Add [-AllMailboxes <Boolean>] [-DeltaSync <String>]
MED - Check any for any custom Admin changes
#>

Param 
(
    [Parameter(Mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [Boolean]$EnableMailboxLoginAudit,
    [Parameter(Mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [Int]$DifferentialScope = 100,
    [Parameter(Mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [String]$AutomationPSCredential,
    [Parameter(Mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [String]$EXOAutomationPSConnection,
    [Parameter(Mandatory = $False)]
    [ValidatePattern('(?i)\S\.onmicrosoft.com$')]
    [ValidateNotNullOrEmpty()]
    [String]$EXOOrganization,
    [Parameter(Mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [Switch]$WhatIf
)

    #Set VAR
    $counter = 0

    # Success Strings
    $sString0 = "CMDlet:Set-Mailbox"

    # Info Strings
    $iString0 = "Collecting STARTED - Where Mailboxes AuditEnabled -ne 'true'"
    $iString1 = "Collecting COMPLETED - Mailboxes Found: "
    $iString2 = "Processing Mailboxes"
    $iString3 = "Hey! No mailboxes found which need AuditEnabled. Let's end this here"

    # Warn Strings
    $wString0 = ""

    # Error Strings
    $eString0 = "Hey! "
    $eString1 = "Hey! No mailboxes found which need AuditEnabled. Let's end this here"
    $eString2 = "FAIL:CMDlet:Set-Mailbox"
    $eString3 = "Hey! You hit the -DifferentialScope limit of $DifferentialScope. Let's break out of this loop"

# Debug Strings
    #$dString1 = ""

    #Load Functions

    function Write-Log([string[]]$Message, [string]$LogFile = $Script:LogFile, [switch]$ConsoleOutput, [ValidateSet("SUCCESS", "INFO", "WARN", "ERROR", "DEBUG")][string]$LogLevel)
    {
    <# 
    .NOTES
        Author: AARON GUILMETTE - With an add from us for azure automation. https://www.undocumented-features.com/2018/02/05/yet-another-write-log-function/
    #>
           $Message = $Message + $Input
           If (!$LogLevel) { $LogLevel = "INFO" }
           switch ($LogLevel)
           {
                  SUCCESS { $Color = "Green" }
                  INFO { $Color = "White" }
                  WARN { $Color = "Yellow" }
                  ERROR { $Color = "Red" }
                  DEBUG { $Color = "Gray" }
           }
           if ($Message -ne $null -and $Message.Length -gt 0)
           {
                $TimeStamp = [System.DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
                if ($LogFile -ne $null -and $LogFile -ne [System.String]::Empty)
                {
                        Out-File -Append -FilePath $LogFile -InputObject "[$TimeStamp] [$LogLevel] $Message"
                }
                if ($ConsoleOutput -eq $true)
                {
                    Write-Host "[$TimeStamp] [$LogLevel] :: $Message" -ForegroundColor $Color

                    if($AutomationPSCredential -or $EXOAutomationPSConnection)
                    {
                        Write-Output "[$TimeStamp] [$LogLevel] :: $Message"
                    }
                }
                if($LogLevel -eq "ERROR")
                {
                        Write-Error "[$TimeStamp] [$LogLevel] :: $Message"
                }
           }
    }

    #Validate Input Values From Parameter 

    Try{
        
        If($EXOAutomationPSConnection -and $EXOOrganization){
            
            #Connect Exchange
            $EXOConnection = Get-AutomationConnection -Name $EXOAutomationPSConnection
            #Connect-ExchangeOnline -CertificateThumbprint $EXOCert.Thumbprint -AppId $EXOAppId -ShowBanner:$false -Organization $EXOCertificateOrganization
            Connect-ExchangeOnline -CertificateThumbprint $EXOConnection.CertificateThumbprint -AppId $EXOConnection.ApplicationId -Organization $EXOOrganization -ShowBanner:$false
            
        }
        Else
        {
            Remove-Variable EXOAutomationPSConnection
            Remove-Variable EXOORGANIZATION
        }

        if ($AutomationPSCredential -and (-not($EXOAutomationPSConnection))) {
            
            $Credential = Get-AutomationPSCredential -Name $AutomationPSCredential

            #Connect-AzureAD -Credential $Credential
            
            $ExchangeOnlineSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Credential -Authentication Basic -AllowRedirection -Name $ConnectionName 
            Import-Module (Import-PSSession -Session $ExchangeOnlineSession -AllowClobber -DisableNameChecking) -Global

        }

        Write-Log -Message "$iString0" -LogLevel INFO -ConsoleOutput
        
        #Get All Mailboxes without 
        $Mailboxes = Get-Mailbox -Filter "AuditEnabled -ne '$true' -and (PersistedCapabilities -ne 'BPOS_S_EquivioAnalytics') -and (PersistedCapabilities -ne 'M365Auditing')" #-ResultSize Unlimited

        #Check if Owners Group is $Null
        $MailboxesNull = $False
        $MailboxesCount = ($Mailboxes | Measure-Object).count
        if($MailboxesCount -eq 0){
            $MailboxesNull = $True
            If($?){
                
                Write-Log -Message $iString3 -LogLevel INFO -ConsoleOutput
                Break

            }
        }
        If(-not $MailboxesNull){
            Write-Log -Message "$iString1 $MailboxesCount" -LogLevel INFO -ConsoleOutput
        }
    }
    
    Catch{
    
        $ErrorMessage = $_.Exception.Message

        If($?){Write-Log -Message $ErrorMessage -LogLevel Error -ConsoleOutput}

        Break

    }
    
    Write-Log -Message "$iString2 " -LogLevel INFO -ConsoleOutput
    foreach ($mbx in $Mailboxes) {
        
        If($counter -lt $DifferentialScope){
            
            If($WhatIf){
                Set-Mailbox -Identity $mbx.Guid.ToString() -AuditEnabled $true -WhatIf
                if($?){Write-Log -Message "$counter;$sString0;AuditEnabled:true;UPN:$($mbx.UserPrincipalName);ObjectId:$($mbx.Guid)" -LogLevel SUCCESS -ConsoleOutput}
                
                if($EnableMailboxLoginAudit){
                    Set-Mailbox -Identity $mbx.Guid.ToString() -AuditOwner @{add='MailboxLogin'} -WhatIf
                    if($?){Write-Log -Message "$counter;$sString0;AuditOwner:add=MailboxLogin;UPN:$($mbx.UserPrincipalName);ObjectId:$($mbx.Guid)" -LogLevel SUCCESS -ConsoleOutput}
                }

                #Increase the count post change
                $counter++
            }
            Else{
                Set-Mailbox -Identity $mbx.Guid.ToString() -AuditEnabled $true
                if($?){Write-Log -Message "$sString0;AuditEnabled:true;UPN:$($mbx.UserPrincipalName);ObjectId:$($mbx.Guid)" -LogLevel SUCCESS -ConsoleOutput}
                Else{
                    $ErrorMessage = $_.Exception.Message
                    Write-Log -Message "$counter;$eString2;AuditEnabled:true;UPN:$($mbx.UserPrincipalName);ObjectId:$($mbx.Guid);Error:$ErrorMessage" -LogLevel ERROR -ConsoleOutput
                }
                
                if($EnableMailboxLoginAudit){
                    Set-Mailbox -Identity $mbx.Guid.ToString() -AuditOwner @{add='MailboxLogin'}
                    if($?){Write-Log -Message "$sString0;AuditOwner:add=MailboxLogin;UPN:$($mbx.UserPrincipalName);ObjectId:$($mbx.Guid)" -LogLevel SUCCESS -ConsoleOutput}
                }

                #Increase the count post change
                $counter++
            }
        }
        else {
                    
            #Exceeded couter limit
            Write-log -Message $eString3 -ConsoleOutput -LogLevel ERROR
            Break

        }  
    }

