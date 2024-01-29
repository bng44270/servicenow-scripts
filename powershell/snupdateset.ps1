###################################
#
# Analyze ServiceNow Update Sets
#
# Usage:
#
#    Get Information on Parent Update Set
#    
#       Get-SNUpdateSet -File /path/to/update_set.xml
#    
#    Get Listing of Updates within Update Set
#
#       Get-SNUpdateSet -File /path/to/update_set.xml -Updates $true
#
#    Get Listing of Updates within Update Set (with parsed payload)
#
#       Get-SNUpdateSet -File /path/to/update_set.xml -Payload $true
#
#    Get Payload Listing of Update set
#
#       Get-SNUpdateSet -File /path/to/update_set.xml -Payload $true | Where-Object { $_.Table -eq "table-name" -and $_.SysId -eq "sys-id" } | Expand-Object -Property Record
#
###################################

function Get-Xml($File) {
	[xml]([string](Get-Content $File))
}

function Expand-Object {
	Param(
		[Parameter(ValueFromPipeline)]$stdin,
		[string]$Property
	)
	$stdin | Select-Object -Property $Property -ExpandProperty $Property
}


function Get-SNUpdateSet($File,$Updates=$False,$Payload=$False) {
	if ($Updates) {
		(Get-Xml $File).unload.sys_update_xml | ForEach-Object {
			[pscustomobject]@{
				"Action"=$_.action
				"Name"=$_.name
				"UpdatedBy"=$_.sys_updated_by
				"UpdatedOn"=$_.sys_updated_on
			}
		}
	}
	if ($Payload) {
		(Get-Xml $File).unload.sys_update_xml | ForEach-Object {
			$thisobject = If ($_.payload.'#cdata-section') { [psobject](([xml]($_.payload.'#cdata-section')).record_update) } Else { [psobject](([xml]($_.payload)).record_update) }
			$thistable = if ($thisobject.table) { $thisobject.table } Else { ([xml]($thisobject.InnerXml)).FirstChild.Name }
			[pscustomobject]@{
				"Table" = $thistable
				"SysId" = $thisobject."$thistable".sys_id
				"Record" = $thisobject."$thistable"
			}
		}
	}
	else {
		(Get-Xml $File).unload.sys_remote_update_set
	}
}