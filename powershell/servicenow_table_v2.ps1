function New-ServiceNowConnection() {
    return [pscustomobject]@{
        "creds" = (Get-Credential)
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
      
        if ($Exists -eq $Null) {
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

function Invoke-ServiceNowAttach($Connection, $Table, $SysId, $FilePath) {
    $sncred = $Connection.creds
    $snhost = $Connection.host
      
    $UploadData = [System.IO.File]::ReadAllBytes($FilePath)
    $FileName = (Get-Item $FilePath).Name

    $resp = (Invoke-WebRequest -Headers @{ "Accept" = "application/json" ; "Content-Type" = "application/octet-stream" } -Body $UploadData -Method POST -Credential $sncred "https://$snhost/api/now/attachment/file?table_name=$Table&table_sys_id=$SysId&file_name=$FileName")
      
    return ($resp.StatusCode - 200) -lt 100
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
    # Query param must be an instance of New-ServiceNowQueryBuilder
    # Specifiy custom Limit param to set result limit 
    $returnValue = $False

    $sncred = $Connection.creds
    $snhost = $Connection.host
    
    $QueryText = $Query.GetQuery()
    
    $resp = Invoke-WebRequest -Method Get -Credential $sncred "https://$snhost/api/now/table/$Table`?sysparm_query=$QueryText&sysparm_limit=$Limit"
    
    if (($resp.StatusCode - 200) -lt 100) {
        $returnValue = ($resp.Content | ConvertFrom-Json).result
    }

    return $returnValue
  }

function Invoke-ServiceNowImageUpload($Connection, $Table, $SysId, $ImageField, $FilePath) {
    $ContentTypeList = @{
        ".jpg" = "image/jpeg"
        ".jpeg" = "image/jpeg"
        ".png" = "image/png"
    }

    $returnValue = $false

    $sncred = $Connection.creds
    $snhost = $Connection.host
    
    $FileObj = (Get-Item $FilePath)
    $FileType = $FileObj.Extension
    $FileName = $FileObj.Name

    $UploadData =  [IO.File]::ReadAllBytes($FilePath)
    
    
    $resp = (Invoke-WebRequest -Headers @{ "Accept" = "application/json" ; "Content-Type" = "application/octet-stream" } -Body $UploadData -Method Post -Credential $sncred "https://$snhost/api/now/attachment/file?table_name=ZZ_YY$Table&table_sys_id=$SysId&file_name=$FileName")

    if (($resp.StatusCode - 200) -lt 100) {
        $attachmentId = ($resp.Content | ConvertFrom-Json).result.sys_id
    
        $UpdateData = (New-ServiceNowData)
        $UpdateData.SetValue('file_name',$ImageField)
        $UpdateData.SetValue('table_name',"ZZ_YY$Table")
        $UpdateData.SetValue('content_type',$ContentTypeList[$FileType])

        $resp = (Invoke-ServiceNowUpdate -Connection $Connection -Table sys_attachment -SysId $attachmentId -Data $UpdateData)

        $returnValue = ($resp.StatusCode - 200) -lt 100
    }

    return $returnValue
}
