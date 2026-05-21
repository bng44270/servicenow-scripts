####################
#
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
#     NOTE:  The object returned from New-ServiceNowQuery supports the following operators:
#              
#            Contains, Is, IsNot, IsEmpty, IsNotEmpty, StartsWith, EndsWith, and In        <--  All accept a single string value except "In" which accepts an array
#
#     If performing an insert or an update, setup necessary data:
#
#        $data = (New-ServiceNowData)
#        $data.SetValue("short_description","This is the new short description")
#        $data.SetValue("caller_id","abel.tuter@example.com")
#
#  3. Run the one of the operation functions:
#
#        $resp = (Invoke-ServiceNowQuery -Connection $conn -Table "incident" -Query $queryBuilder)
#
#            OR (Invoke-ServiceNowQuery can you -Query or -SysId - NOT BOTH)
#
#        $resp = (Invoke-ServiceNowQuery -Connection $conn -Table "incident" -SysId "1bc4415dcfc634c5e9e45b053273f3e0")
#        
#        $resp = (Invoke-ServiceNowInsert -Connection $conn -Table "incident" -Data $data)
#        
#        $resp = (Invoke-ServiceNowUpdate -Connection $conn -Table "incident" -SysId "87976f52ea9130aaccfa3b5ebbd3f109" -Data $data)
#
#     NOTE:  The value for Query parameter for Invoke-ServiceNowQuery must be created with New-ServiceNowQueryBuilder
#
#     NOTE:  The value for Data parameter for Invoke-ServiceNowInsert and Invoke-ServiceNowUpdate must be created with New-ServiceNowData
#
#     NOTE:  The Invoke-ServiceNowQuery command accepts the following optional arguments:
#
#                 -Limit <number of records, defaults to 10,000>
#
#                 -Offset <record offset to begin returning, defaults to 0>
#
#                 -Fields <array containing fields to return, returns all fields by default>
#                       array example:
#                            $usefields = @()
#                            $usefields += "number"
#                            $useFields += "short_description"
#
#
#  Upload attachments to a record:
#      
#        Invoke-ServiceNowAttach -Connection $conn -Table "incident" -SysId "" -FilePath "c:\folder\file.doc"
#
#  Upload image to a record and display it in an image field:
#      
#        Invoke-ServiceNowAttach -Connection $conn -Table "incident" -SysId "" -FilePath "c:\folder\file.jpg" -ImageField "u_image_field"
#
####################

function New-ServiceNowConnection() {
  return [pscustomobject]@{
    "creds" = (Get-Credential -Title "New ServiceNow Connection")
    "host"  = (Read-Host -Prompt "Host")
  }
}
  
function New-ServiceNowData() {
  $ob = [pscustomobject]@{
    "data" = [pscustomobject]@{}
  }
    
  $ob | Add-Member -MemberType ScriptMethod -Name "SetValue" -Value {
    param($fp, $vp)
    $Exists = (Get-Member -InputObject $this.GetData() -Name $fp)
      
    if ($Null -eq $Exists) {
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
  
function Invoke-ServiceNowInsert($Connection, $Table, $Data) {
  # $Connection should be an instance of New-ServiceNowConnection
  # $Data should be an instance of New-ServiceNowData
  $sncred = $Connection.creds
  $snhost = $Connection.host
    
  $postJson = ($Data.GetData() | ConvertTo-Json)
  
  $resp = (Invoke-WebRequest -Headers @{ "Accept" = "application/json" ; "Content-Type" = "application/json" } -Body $postJson -Method POST -Credential $sncred "https://$snhost/api/now/table/$Table")
  
  $returnValue = $False
  
  if (($resp.StatusCode - 200) -lt 100) {
    $returnValue = ($resp.Content | ConvertFrom-Json).result.sys_id
  }
    
  return $returnValue
}
  
function Invoke-ServiceNowUpdate($Connection, $Table, $SysId, $Data) {
  $sncred = $Connection.creds
  $snhost = $Connection.host
      
  $postJson = ($Data.GetData() | ConvertTo-Json)
  $resp = (Invoke-WebRequest -Headers @{ "Accept" = "application/json" ; "Content-Type" = "application/json" } -Body $postJson -Method PUT -Credential $sncred "https://$snhost/api/now/table/$Table/$SysId")
      
  return ($resp.StatusCode - 200) -lt 100
}

function New-ServiceNowQueryBuilder($IsOr = $False) {
  $ob = [pscustomobject]@{
    "isor"  = $IsOr
    "qar"   = @()
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
  }
    
  $ob | Add-Member -MemberType ScriptMethod -Name "Contains" {
    param($v)
      
    return ($this.name + "CONTAINS" + $v)
  }
      
  $ob | Add-Member -MemberType ScriptMethod -Name "Is" {
    param($v)
      
    return ($this.name + "=" + $v)
  }

  $ob | Add-Member -MemberType ScriptMethod -Name "IsNot" {
    param($v)
      
    return ($this.name + "!=" + $v)
  }

  $ob | Add-Member -MemberType ScriptMethod -Name "IsEmpty" {
    return ($this.name + "ISEMPTY")
  }

  $ob | Add-Member -MemberType ScriptMethod -Name "IsNotEmpty" {
    return ($this.name + "ISNOTEMPTY")
  }
      
  $ob | Add-Member -MemberType ScriptMethod -Name "StartsWith" {
    param($v)
      
    return ($this.name + "STARTSWITH" + $v)
  }
      
  $ob | Add-Member -MemberType ScriptMethod -Name "EndsWith" {
    param($v)
      
    return ($this.name + "ENDSWITH" + $v)
  }

  $ob | Add-Member -MemberType ScriptMethod -Name "In" {
    param($a)

    return ($this.name + "IN" + ($a -join ','))
  }
      
  return $ob 
}
  
function Invoke-ServiceNowQuery($Connection, $Table, $Query = (New-ServiceNowQueryBuilder), $SysId = "", $Limit = 0, $Offset = 0, $Fields = @()) {
  # Query param must be an instance of New-ServiceNowQueryBuilder
  $returnValue = $False

  $sncred = $Connection.creds
  $snhost = $Connection.host
    
  $ReqUrl = "$Table";

  if ($SysId.Length -gt 0) {
    $ReqUrl += "/$SysId"
  }
  else {
    $ReqUrl += ("`?sysparm_query=" + $Query.GetQuery())
    
    if ($Limit -gt 0) {
      $ReqUrl += ("&sysparm_limit=" + $Limit.ToString())
    }

    if ($Offset -gt 0) {
      $ReqUrl +=  ("&sysparm_offset=" + $Offset.ToString())
    }

    if ($Fields.Length -gt 0) {
      $ReqUrl += ("&sysparm_fields=" + ($Fields -join ","))
    }
  }

  $resp = Invoke-WebRequest -Method Get -Credential $sncred "https://$snhost/api/now/table/$ReqUrl"
    
  if (($resp.StatusCode - 200) -lt 100) {
    $returnValue = ($resp.Content | ConvertFrom-Json).result
  }

  return $returnValue
}

function Invoke-ServiceNowAttach($Connection, $Table, $SysId, $FilePath, $ImageField = "") {
  $ContentTypeList = @{
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".png"  = "image/png"
  }

  $returnValue = $false

  $sncred = $Connection.creds
  $snhost = $Connection.host
    
  $FileObj = (Get-Item $FilePath)
  $FileType = $FileObj.Extension
  $FileName = $FileObj.Name

  $UploadData = [IO.File]::ReadAllBytes($FilePath)
    
  $UseTable = $ImageField.Length -eq 0 ? $Table : "ZZ_YY$Table"
    
  $resp = (Invoke-WebRequest -Headers @{ "Accept" = "application/json" ; "Content-Type" = "application/octet-stream" } -Body $UploadData -Method Post -Credential $sncred "https://$snhost/api/now/attachment/file?table_name=$UseTable&table_sys_id=$SysId&file_name=$FileName")

  $returnValue = $false

  if (($resp.StatusCode - 200) -lt 100) {
    $returnValue = $true

    if ($ImageField.Length -gt 0) {
      $attachmentId = ($resp.Content | ConvertFrom-Json).result.sys_id
      $UpdateData = (New-ServiceNowData)
      $UpdateData.SetValue('file_name', $ImageField)
      $UpdateData.SetValue('table_name', $UseTable)
      $UpdateData.SetValue('content_type', $ContentTypeList[$FileType])

      $resp = (Invoke-ServiceNowUpdate -Connection $Connection -Table sys_attachment -SysId $attachmentId -Data $UpdateData)

      $returnValue = ($resp.StatusCode - 200) -lt 100
    }
  }

  return $returnValue
}
