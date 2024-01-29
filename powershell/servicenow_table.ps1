####################
# ServiceNow Table API Library for Powershell
#
# Usage:
#  1. Define connection (host, user, password):
#
#        $conn = (New-ServiceNowConnection)
#
#  2. If performing an query, setup the query:
#     (set the "IsOr" argument to $True for New-ServiceNowQueryBuilder function if query is using boolean OR):
#
#        $queryBuilder = (New-ServiceNowQueryBuilder)
#        $linuxQuery = (New-ServiceNowQuery -FieldName "short_description").Contains("linux")
#        $activeQuery = (New-ServiceNowQuery -FieldName "active").Is("true")
#        $queryBuilder.Add($linuxQuery)
#        $queryBuilder.Add($activeQuery)
#
#     If performing an insert or an update, setup necessary data:
#
#        $data = (New-ServiceNowData)
#        $data.SetValue("short_description","This is the new short description")
#        $data.SetValue("caller_id","abel.tuter@example.com")
#
#  3. Run the one of the operation functions:
#
#        $resp = (Invoke-ServiceNowQuery -Connection $conn -Table "incident" -Query $query)
#        
#        $resp = (Invoke-ServiceNowInsert -Connection $conn -Table "incident" -Data $data)
#        
#        $resp = (Invoke-ServiceNowUpdate -Connection $conn -Table "incident" -SysId "87976f52ea9130aaccfa3b5ebbd3f109" -Data $data)
#
#  4. To extract the created/updated record from the response of step 3:
#
#        $record = (Get-ServiceNowRecord -Response $resp)
#
#  5. To extract data about a reference field from the record of step 4 (in this example the caller_id field is being used):
#
#        $reference = (Get-ServiceNowReference -Field $record.caller_id)
#
#  6. To query using the reference object from step 5:
#
#        $refrecord = (Invoke-ServiceNowReferenceQuery -Connection $conn -Reference $reference)
#
####################

function New-ServiceNowConnection() {
  return [pscustomobject]@{
    "creds" = (Get-Credential)
    "host" = (Read-Host -Prompt "Host")
  }
}

function New-ServiceNowData() {
  $ob = [pscustomobject]@{
    "data" = [pscustomobject]@{}
  }
  
  $ob | Add-Member -MemberType ScriptMethod -Name "SetValue" -Value {
    param($fp,$vp)
    $Exists = (Get-Member -InputObject $this.GetData() -Name $fp)
    
    if ($Exists -eq $null) {
      $this.data | Add-Member -MemberType NoteProperty -Name $fp -Value $vp    
    }
    else {
      $this.data.$fp = $vp
    }
    
  }
  
  $ob | Add-Member -MemberType ScriptMethod -Name "GetData" -Value {
    return $this.data
  }
  
  return $ob
}

function New-ServiceNowQueryBuilder($IsOr=$False) {
  $ob = [pscustomobject]@{
    "isor" = $IsOr
    "qar" = @()
    "query" = ""
  }
  
  $ob | Add-Member -MemberType ScriptMethod -Name "Add" -Value {
    param($q)
    
    $this.qar += $q
  }
  
  $ob | Add-Member -MemberType ScriptMethod -Name "GetQuery" -Value {
    $returnValue = $null
    
    if ($this.isor) {
      $returnValue = ($this.qar -join "^OR")
    }
    else {
      $returnValue = ($this.qar -join "^")
    }
    
    return $returnValue
  }
  
  return $ob
}

function New-ServiceNowQuery($FieldName) {
  $ob = [pscustomobject]@{
    "name" = $FieldName
    "qar" = @()
    "query" = ""
  }
  
  $ob | Add-Member -MemberType ScriptMethod -Name "Contains" {
    param($v)
    
    return ($this.name + "CONTAINS" + $v)
  }
    
  $ob | Add-Member -MemberType ScriptMethod -Name "Is" {
    param($v)
    
    return ($this.name + "=" + $v)
  }
    
  $ob | Add-Member -MemberType ScriptMethod -Name "StartsWith" {
    param($v)
    
    return ($this.name + "STARTSWITH" + $v)
  }
    
  $ob | Add-Member -MemberType ScriptMethod -Name "EndsWith" {
    param($v)
    
    return ($this.name + "ENDSWITH" + $v)
  }
    
  return $ob 
}

function Invoke-ServiceNowQuery($Connection,$Table,$Query,$Limit=10000) {
  $sncred = $Connection.creds
  $snhost = $Connection.host
  
  $QueryText = $Query.GetQuery()
  
  $resp = Invoke-WebRequest -Method Get -Credential $sncred "https://$snhost/api/now/table/$Table`?sysparm_query=$QueryText&sysparm_limit=$Limit"
  
  return $resp
}

function Invoke-ServiceNowInsert($Connection,$Table,$Data) {
  $sncred = $Connection.creds
  $snhost = $Connection.host
  
  $resp = ($Data.GetData() | ConvertTo-Json | Invoke-WebRequest -Headers @{ "Accept" = "application/json" ; "Content-Type" = "application/json" } -Method POST -Credential $sncred "https://$snhost/api/now/table/$Table")
  
  return $resp
}

function Invoke-ServiceNowUpdate($Connection,$Table,$SysId,$Data) {
  $sncred = $Connection.creds
  $snhost = $Connection.host
  
  $resp = ($Data.GetData() | ConvertTo-Json | Invoke-WebRequest -Headers @{ "Accept" = "application/json" ; "Content-Type" = "application/json" } -Method PUT -Credential $sncred "https://$snhost/api/now/table/$Table/$SysId")
  
  return $resp
}

function Get-ServiceNowResult($Response) {
  return (($Response.result).Content | ConvertFrom-Json).result
}

function Get-ServiceNowReference($Field) {
  $Field.link -replace '^.*\/table\/([^\/]+)\/(.*)$','{"table":"$1","sys_id":"$2"}' | ConvertFrom-Json
}

function Invoke-ServiceNowReferenceQuery($Connection,$Reference) {
  $qb = (New-ServiceNowQueryBuilder)
  $q = (New-ServiceNowQuery -Field "sys_id").Is($Reference.sys_id)
  $qb.Add($q)
  
  return (Invoke-ServiceNowQuery -Connection $Connection -Table $Reference.table -Query $qb)
}

function Out-ServiceNowRecordList($Fields,$Result) {
	$allfields = $Fields + @("sys_id")
	
  return ($Result | Select-Object -Property $allfields | Out-GridView -PassThru)
}

function Open-ServiceNowView($Connection,$Table,$SysId) {
  $snhost = $Connection.host
  
  Start "https://$snhost/$Table.do?sys_id=$SysId"
}