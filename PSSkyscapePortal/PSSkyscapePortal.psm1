$Global:SkyscapeURL = ""
$Global:Headers = @{"Content-Type" = "application/json"}
$Global:SkyscapeSession = $null
  
Function New-SkyscapePortalLogin($Username,$Password,$IL)
{
	$Data = @"
{"email": "$username", "password": "$password"}
"@
	
	if($IL -eq 2)
	{
		$Global:SkyscapeURL = "https://portal.skyscapecloud.com/api"	
	}
	else
	{
		$Global:SkyscapeURL = "https://portal.skyscapecloud.gsi.gov.uk/api"	
	}
	
	$Res = Invoke-WebRequest -Method Post -Headers $Global:Headers -Uri "$($Global:SkyscapeURL)/authenticate" -Body $Data -SessionVariable LocalSession
	$Global:SkyscapeSession = $LocalSession
	Return $Res
}

Function Invoke-SkyscapeRequest($URL)
{
	if($Global:SkyscapeSession -ne $null)
	{
		$Res = Invoke-WebRequest -Method Get -Headers $Global:Headers -Uri $URL -WebSession $Global:SkyscapeSession
	}
	else
	{
		Write-Warning "Please connect to the Skyscape Portal first using the New-SkyscapePortalLogin cmdlet"
		$Res = $Null
	}
	Return $Res
}

Function Invoke-SkyscapePUTRequest($URL,$Data)
{
	if($Global:SkyscapeSession -ne $null)
	{
		$Res = Invoke-WebRequest -Method PUT -Headers $Global:Headers -Uri $URL -WebSession $Global:SkyscapeSession -Body $Data
	}
	else
	{
		Write-Warning "Please connect to the Skyscape Portal first using the New-SkyscapePortalLogin cmdlet"
		$Res = $Null
	}
	Return $Res
}

Function Invoke-SkyscapePOSTRequest($URL,$Data)
{
	if($Global:SkyscapeSession -ne $null)
	{
		$Res = Invoke-WebRequest -Method POST -Headers $Global:Headers -Uri $URL -WebSession $Global:SkyscapeSession -Body $Data
	}
	else
	{
		Write-Warning "Please connect to the Skyscape Portal first using the New-SkyscapePortalLogin cmdlet"
		$Res = $Null
	}
	Return $Res
}

Function Get-SkyscapeTickets([Switch]$ForAccount)
{
	if($ForAccount)
	{
		$UserTickets = Get-SkyscapeTickets
		$Res = Invoke-SkyscapeRequest -URL "$($Global:SkyscapeURL)/my_calls?for=account"
		$Tickets = ($Res.content | ConvertFrom-Json)
		ForEach($Ticket in $Tickets)
		{
			$Check = ($UserTickets | ?{$_.TicketID -eq $Ticket.Ticket_ID} | Measure-Object).count
			if($Check -gt 0)
			{
				$Ticket | Add-Member -MemberType NoteProperty -Name "IsUser" -Value $true -Force
			}
			else
			{
				$Ticket | Add-Member -MemberType NoteProperty -Name "IsUser" -Value $False -Force
			}
		}
	}
	else
	{
		$Res = Invoke-SkyscapeRequest -URL "$($Global:SkyscapeURL)/my_calls?for=user"
		$Tickets = ($Res.content | ConvertFrom-Json)
	}
	Return $Tickets
}

Function Get-SkyscapeTicketData($Ticket,[switch]$ForAccount)
{
	if($Ticket.IsUser)
	{
		$ForAccount = $False
	}
	else
	{
		$ForAccount = $True
	}
	$TicketID = $Ticket.ticket_id
	
	if($ForAccount)
	{
		$Res = Invoke-SkyscapeRequest -URL "$($Global:SkyscapeURL)/my_calls/$($TicketID)?for=account"
		
	}
	else
	{
		$Res = Invoke-SkyscapeRequest -URL "$($Global:SkyscapeURL)/my_calls/$($TicketID)?for=user"
		
	}
	Return ($Res.content | ConvertFrom-Json)
}

Function Get-SkyscapeTicketReport($ExportPath,[switch]$Open)
{
	$Tickets = Get-SkyscapeTickets -ForAccount
	if($Open)
	{
		$Tickets = $Tickets | ?{$_.status -ne "Closed"}
	}
	$TicketReport = @()
	$TTotal = ($Tickets | Measure-Object).count
	$I = 0
	ForEach($Ticket in $Tickets)
	{
		$I += 1
		$P = ($I/$TTotal)*100
		Write-Progress -Activity "Processing" -Status "$($Ticket.Ticket_ID)" -PercentComplete $P -Id 0
		$TicketData = Get-SkyscapeTicketData -Ticket $Ticket
		
		if(($TicketData.updates | Measure-Object).count -gt 0)
		{
			$UTotal = ($TicketData.Updates | Measure-Object).count
			$UI = 0
			$UpdateCounter = 1
			ForEach($Update in $TicketData.updates)
			{
				$UI += 1
				$UP = ($UI/$UTotal)*100
				Write-Progress -Activity "Processing Updates" -Status "$($UI)" -PercentComplete $UP -Id 1
				$Holder = "" | Select Ticket_ID,Summary,Submitted,Status,Description,HasUpdates,UpdateID,UpdateType,UpdateText,UpdateBy,UpdatedOn
				$Holder.Ticket_ID = $Ticket.ticket_id
				$Holder.Summary = $Ticket.summary
				$Holder.Submitted = $Ticket.submitted
				$Holder.Status = $Ticket.Status
				$Holder.Description = $TicketData.ticket.Description
				$Holder.HasUpdates = $True
				$Holder.UpdateID = $UpdateCounter
				$Holder.UpdateType = $Update.type
				$Holder.UpdateText = $Update.text
				$Holder.UpdateBy = $Update.owner
				$Holder.UpdatedOn = $Update.submitted_on
				$TicketReport += $Holder
				$UpdateCounter += 1
			}
				
		
		}
		else
		{
			$Holder = "" | Select Ticket_ID,Summary,Submitted,Status,Description,HasUpdates,UpdateID,UpdateType,UpdateText,UpdateBy,UpdatedOn
			$Holder.Ticket_ID = $Ticket.ticket_id
			$Holder.Summary = $Ticket.summary
			$Holder.Submitted = $Ticket.submitted
			$Holder.Status = $Ticket.Status
			$Holder.Description = $TicketData.ticket.Description
			$Holder.HasUpdates = $False
			$TicketReport += $Holder
		
		}
	}
	if($ExportPath)
	{
		Write-Host "Exporting report to $ExportPath"
		$TicketReport | Export-Csv -Path $ExportPath -NoTypeInformation
	}
	
	Return $TicketReport
}

Function Get-SkyscapeVMReport($ExportCSVPath)
{
	$Accounts = Get-SkyscapeAccounts
	$Report = @()
	$AccountTotal = ($Accounts | Measure-Object).count
	$AccountCounter = 1
	ForEach($Account in $Accounts)
	{
		$AccountPercentage = ($AccountCounter/$AccountTotal)*100
		$AccountCounter += 1
		Write-Progress -Activity "Processing Account" -Status "$($Account.name)" -PercentComplete $AccountPercentage -Id 0
		
		$VMS = Get-ComputeServicesForAccount -AccountID ($Account.ID)
		
		$OrgTotal = ($vms.vorgs | Measure-Object).count
		$OrgCounter = 1
		ForEach($VORG in $VMS.vorgs)
		{
			$OrgPercentage = ($OrgCounter/$OrgTotal)*100
			$OrgCounter += 1
			Write-Progress -Activity "Processing ORG" -Status "$($VORG.name)" -PercentComplete $OrgPercentage -Id 1
			
			$VDCTotal = ($VORG.VDCs | Measure-Object).count
			$VDCCounter = 1
			ForEach($VDC in $VORG.VDCs)
			{
				$VDCPercentage = ($VDCCounter/$VDCTotal)*100
				$VDCCounter += 1
				Write-Progress -Activity "Processing VDC" -Status "$($VDC.name)" -PercentComplete $VDCPercentage -Id 2
				
				$VAPPTotal = ($VDC.vApps | Measure-Object).count
				$VAPPCounter = 1
				ForEach($VAPP in $VDC.vApps)
				{
					$VAPPPercentage = ($VAPPCounter/$VAPPTotal)*100
					$VAPPCounter += 1
					Write-Progress -Activity "Processing VAPP" -Status "$($VAPP.name)" -PercentComplete $VAPPPercentage -Id 3
					
					$VMTotal = ($VAPP.VMs | Measure-Object).count
					$VMCounter = 1
					ForEach($VM in $VAPP.VMs)
					{
						$VMPercentage = ($VMCounter/$VMTotal)*100
						$VMCounter += 1
						Write-Progress -Activity "Processing VM" -Status "$($VM.name)" -PercentComplete $VMPercentage -Id 4
						$Holder = "" | Select Account,ORG,ORGID,VDC,VAPP,Name,MonthToDate,EstimatedMonthlyTotal,BilledHoursOn,BilledHoursOff,PowerStatus,OS,CPUs,Memory,Storage
						$Holder.Account = $Account.name
						$Holder.ORG = $VORG.name
						$Holder.ORGID = $VORG.serviceId
						$Holder.VDC = $VDC.name
						$Holder.VAPP = $VAPP.name
						$Holder.Name = $VM.name
						$Holder.MonthToDate = $VM.monthToDate
						$Holder.EstimatedMonthlyTotal = $VM.estimatedMonthlyTotal
						$Holder.BilledHoursOn = $VM.billedHoursPoweredOn
						$Holder.BilledHoursOff = $VM.billedHoursPoweredOff
						$Holder.PowerStatus = $VM.powerStatus
						$Holder.OS = $VM.operatingSystem
						$Holder.CPUs = $VM.numberOfCPUs
						$Holder.Memory = $VM.memory
						$Holder.Storage = $VM.storage
						$Report += $Holder
					}
				}
			}
		}
	}
		
	if($ExportCSVPath)
	{
		$Report | Export-Csv -Path $ExportCSVPath -NoTypeInformation
	}
	Return $Report
}

Function New-SkyscapeTicketUpdate($TicketID,$UpdateText)
{
	$Body = @"
{"description": "$UpdateText"}
"@
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)" -data $Body
	Return ($Res.content | ConvertFrom-Json)
}

Function Set-SkyscapeTicketOwner($TicketID,$OwnerEmail)
{
	$Body = @"
{"email": "$YourEmail"}	
"@
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/change_owner" -data $Body
	Return ($Res.content | ConvertFrom-Json)
}

Function Get-SkyscapeTicketSubscription($TicketID,$YourEmail)
{
	$Body = @"
{"email": "$YourEmail"}	
"@
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/subscribe" -data $Body
	Return ($Res.content | ConvertFrom-Json)
}

Function Remove-SkyscapeTicketSubscription($TicketID,$YourEmail)
{
	$Body = @"
{"email": "$YourEmail"}	
"@
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/unsubscribe" -data $Body
	Return ($Res.content | ConvertFrom-Json)
}

Function ReOpen-SkyscapeTicket($TicketID)
{
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/reopen" -data $null
	Return ($Res.content | ConvertFrom-Json)

}

Function Cancel-SkyscapeTicket($TicketID)
{
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/cancel" -data $null
	Return ($Res.content | ConvertFrom-Json)

}

Function Close-SkyscapeTicket($TicketID)
{
	$Res = Invoke-SkyscapePUTRequest -url "$($Global:SkyscapeURL)/my_calls/$($TicketID)/close" -data $null
	Return ($Res.content | ConvertFrom-Json)

}

Function Test-SkyscapePortal()
{
	$Res = Invoke-SkyscapeRequest -url "$($Global:SkyscapeURL)/ping"
	Return ($Res.content | ConvertFrom-Json)

}

Function Get-SkyscapeAccounts()
{
	$Res = Invoke-SkyscapeRequest -url "$($Global:SkyscapeURL)/accounts"
	Return ($Res.content | ConvertFrom-Json)
}

Function Get-ComputeServicesForAccount($AccountID)
{
	$Res = Invoke-SkyscapeRequest -url "$($Global:SkyscapeURL)/accounts/$AccountID/compute_services"
	Return ($Res.content | ConvertFrom-Json)
}