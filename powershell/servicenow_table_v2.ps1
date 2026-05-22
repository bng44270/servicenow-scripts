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
#
#        $queryBuilder = (New-ServiceNowQueryBuilder)
#        $activeQuery = (New-ServiceNowQuery -FieldName "active").Is("true")
#        $stateQuery = (New-ServiceNowQuery -FieldName "state").IsOneOf(@(4,5))
#        $descrQuery = (New-ServiceNowQueryBuilder -IsOr $true)
#        $descrQuery.Add((New-ServiceNowQuery -FieldName "short_description").Contains("linux"))
#        $descrQuery.Add((New-ServiceNowQuery -FieldName "short_description").Contains("windows"))
#        $queryBuilder.Add($activeQuery)
#        $queryBuilder.Add($stateQuery)
#        $queryBuilder.Add($descrQuery)
#
#        # $queryBuilder.GetQuery() => active=true^stateIN4,5^short_descriptionLIKElinux^ORshort_descriptionLIKEwindows
#
#     NOTE:  The object returned from New-ServiceNowQuery supports the following methods:
#            
#            Is(value)                }
#            IsNot(value)             }
#            Contains(value)          }
#            DoesNotContains(value)   }  Compares provided value to field value
#            StartsWith(value)        }
#            EndsWith(value)          }
#
#            IsEmpty()      }
#            IsNotEmpty()   }   Checks field (no argument needed)
#
#            IsDifferent(field)  }
#            IsSame(field)       }   Compares field value to the value of a provided field
#
#            IsGreaterOrEqual(value)   }
#            IsLessOrEqual(value)      }  Compares provided numeric value to field value
#
#            IsOneOf(array) -  Compares field value to values in provided array
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
#            OR (Invoke-ServiceNowQuery can use -Query or -SysId - NOT BOTH)
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
#                            OR
#
#                            $usefields = @("number","short_description")
#
#
#  Attach a file to a record:
#      
#        Invoke-ServiceNowAttach -Connection $conn -Table "incident" -SysId "" -FilePath "c:\folder\file.doc"
#
#  Attach image file to a record and display it in an image field (valid file extension are jpg, jpeg, and png):
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
  }
    
  $ob | Add-Member -MemberType ScriptMethod -Name "Add" -Value {
    param($q)

    $queryType = $q.GetType().Name

    if ($queryType -eq "String") {
      $this.qar += $q
    }
    elseif ($queryType -eq "PSCustomObject") {
      $this.qar += $q.GetQuery()
    } 
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
  
  $ob | Add-Member -MemberType ScriptMethod -Name "IsGreaterOrEqual" {
    param($v)
      
    return ($this.name + ">=" + $v.ToString())
  }

  $ob | Add-Member -MemberType ScriptMethod -Name "IsLessOrEqual" {
    param($v)
      
    return ($this.name + "<=" + $v.ToString())
  }

  $ob | Add-Member -MemberType ScriptMethod -Name "IsSame" {
    param($v)
      
    return ($this.name + "SAMEAS" + $v)
  }

  $ob | Add-Member -MemberType ScriptMethod -Name "IsDifferent" {
    param($v)
      
    return ($this.name + "NSAMEAS" + $v)
  }

  $ob | Add-Member -MemberType ScriptMethod -Name "Contains" {
    param($v)
      
    return ($this.name + "LIKE" + $v)
  }

  $ob | Add-Member -MemberType ScriptMethod -Name "DoesNotContains" {
    param($v)
      
    return ($this.name + "NOT LIKE" + $v)
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

  $ob | Add-Member -MemberType ScriptMethod -Name "IsOneOf" {
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
