# Enable-MailboxAuditing.ps1
This script automates the enabling of the default audit value on mailboxes in Exchange Online. 

```` Powershell

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
