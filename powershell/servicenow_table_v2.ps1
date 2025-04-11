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

function Invoke-ServiceNowLookupPartByOemName($Connection,$OemName) {
    $TableName = 'x_nuvo_eam_facilities_parts'

    $returnValue = $false

    $query = (New-ServiceNowQueryBuilder)
    $partNumQuery = (New-ServiceNowQuery -FieldName "oem_part_name").Is($OemName)
    $query.Add($partNumQuery)

    $result = (Invoke-ServiceNowQuery -Connection $Connection -Table $TableName -Query $query)

    if ($result) {
        $returnValue = ($result | ForEach-Object { $_.sys_id})
    }

    return $returnValue
}

function Create-LogFile($Path, $Name) {
    $obj = [PSCustomObject]@{
        Date = (Get-Date -UFormat "%m-%d-%YT%H-%M-%SZ")
        Path = $Path
        Name = $Name
    }

    $obj | Add-Member -MemberType ScriptMethod -Name "GetFilePath" -Value {
        return ($this.Path + "\" + $this.Name + "-" + $this.Date + ".log")
    }

    return $obj
}

function Write-LogFile($Log, $Text) {
    "$Text" | Out-File ($Log.GetFilePath()) -Append
}

function Invoke-DocumentFolderWalk($Connection, $Folder, $ParentId = "", $Log = (Create-LogFile -Path c:\temp -Name document_migration)) {
    # Folder Table layout
    #      Name
    #      Parent
    $FolderTable = 'FOLDER_TABLE_NAME'
    # Customization to Document Table
    #     Add Parent field referencing the Folder table
    $DocumentTable = 'dms_document'
    $DocumentRevisionTable = 'dms_document_revision'

    if ($ParentId.Length -eq 0) {
        $LogFile = $Log.GetFilePath()
        Write-Output "Writing Log:  $LogFile"
    }

    Get-ChildItem $Folder | ForEach-Object {
        $thisFolderEntry = $_

        # If it is a folder, Mode starts wtih "d"
        if ($thisFolderEntry.Mode -match '^d') {
            $NewFolderData = (New-ServiceNowData)
            $NewFolderData.SetValue("name", $thisFolderEntry.Name)
            
            if ($ParentId.Length -gt 0) {
                $NewFolderData.SetValue("parent", $ParentId);
            }

            $NewParentId = (Invoke-ServiceNowInsert -Connection $Connection -Table $FolderTable -Data $NewFolderData)
            
            $FullFolderPath = $thisFolderEntry.FullName

            if ($NewParentId) {
                Write-LogFile -Log $Log -Text "[SUCCESS] $FullFolderPath created folder successfully"

                Invoke-DocumentFolderWalk -Connection $Connection -Folder $FullFolderPath -ParentId $NewParentId -Log $Log
            }
            else {
                Write-LogFile -Log $Log -Text "[ERROR] $FullFolderPath failed to create"
            }
        }
        else {
            $NewDocumentData = (New-ServiceNowData)
            $NewDocumentData.SetValue("name", $thisFolderEntry.Name)
            $NewDocumentData.SetValue("parent", $ParentId)

            $NewDocumentId = (Invoke-ServiceNowInsert -Connection $Connection -Table $DocumentTable -Data $NewDocumentData)
            
            $FullFilePath = $thisFolderEntry.FullName

            if ($NewDocumentId) {
                Write-LogFile -Log $Log -Text "[SUCCESS] $FullFilePath created document successfully"

                $NewDocumentRevisionData = (New-ServiceNowData)
                $NewDocumentRevisionData.SetValue("name", $thisFolderEntry.Name + "_1")
                $NewDocumentRevisionData.SetValue("stage", "published")
                $NewDocumentRevisionData.SetValue("document", $NewDocumentId)
                $NewDocumentRevisionData.SetValue("approval", "approved")
                $NewDocumentRevisionData.SetValue("author", "4f384a8e1bc8cad0c0af5396624bcbac")
                $NewDocumentRevisionData.SetValue("owner", "4f384a8e1bc8cad0c0af5396624bcbac")
            
                $NewRevisionId = (Invoke-ServiceNowInsert -Connection $Connection -Table $DocumentRevisionTable -Data $NewDocumentRevisionData)
                
                if ($NewRevisionId) {
                    Write-LogFile -Log $Log -Text "[SUCCESS] $FullFilePath created document revision successfully"

                    $UploadSuccess = (Invoke-ServiceNowAttach -Connection $Connection -Table $DocumentRevisionTable -SysId $NewRevisionId -FilePath $FullFilePath)

                    if ($UploadSuccess) {
                        Write-LogFile -Log $Log -Text "[SUCCESS] $FullFilePath uploaded document successfully"
                    }
                    else {
                        Write-LogFile -Log $Log -Text "[ERROR] $FullFilePath failed to uploaded"
                    }
                }
                else {
                    Write-LogFile -Log $Log -Text "[ERROR] $FullFilePath failed to create document revision"
                }
            
            }
            else {
                Write-LogFile -Log $Log -Text "[ERROR] $FullFilePath failed to create document"
            }
            
        }
    }
}
