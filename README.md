# PSSkyscapePortal
Skyscape Portal Powershell Module

Usage

Copy the PSSkyscapePortal folder to your module path, either:

c:\Users\yourusername\Documents\WindowsPowerShell\Modules
c:\Windows\System32\WindowsPowerShell\v1.0\Modules

Open a Powershell session
import-module PSSkyscapePortal

Login

IL2

New-SkyscapePortalLogin -Username "your portal email address" -Password "your portal password" -IL 2

IL3

New-SkyscapePortalLogin -Username "your portal email address" -Password "your portal password" -IL 3

Get VM & Billing Info:

$Report = Get-SkyscapeVMReport

With export:

$Report = Get-SkyscapeVMReport -ExportCSVPath c:\path\to\save\file.csv

Get Ticket Information:

$Report =  Get-SkyscapeTicketReport

With export:

$Report = Get-SkyscapeTicketReport -ExportPath c:\path\to\save\file.csv

Update a ticket:

New-SkyscapeTicketUpdate -TicketID "TicketID" -UpdateText "This is a sample update"



