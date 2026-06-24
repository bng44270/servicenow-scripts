################
# Add the following statements before loading servicenow.psm1 module
#
#       using module Microsoft.PowerShell.Utility
################

class ServiceNowConnection {
    [string] $Hostname
    [pscredential] $Credentials

    ServiceNowConnection([string]$h,[bool]$UseCreds) {
        $this.Hostname = $h
        if ($UseCreds) {
            $this.Credentials = (Get-Credential -Title "ServiceNow Credentials" -Message " ")
        }
    }
    
    ServiceNowConnection([string] $h, [string] $u, [string] $p) {
        $this.Hostname = $h
    
        $usep = $null

        if ($p.GetType().Name -eq "SecureString") {
            $usep = $p
        }
        else {
            $usep = ($p | ConvertTo-SecureString -AsPlainText -Force)
        }
    
        $this.Credentials = [pscredential]::new($u, $usep)
    }

}

class ServiceNowQueryBuilder {
    [string] $Condition
    [System.Collections.ArrayList] $Queries

    ServiceNowQueryBuilder() {
        $this.Condition = "^"
        $this.Queries = [System.Collections.ArrayList]::new()
    }

    [void] MakeOr() {
        $this.Condition = '^OR'
    }

    [void] MakeAnd() {
        $this.Condition = '^'
    }

    [string] Get() {
        return $this.Queries -join $this.Condition
    }

    [void] Append([ServiceNowQueryBuilder] $q) {
        $this.Queries.Add($q.Get())
    }

    [void] GreaterOrEqual([string] $f, [string] $v) {
        $this.Queries.Add($f + ">=" + $v.ToString())
    }

    [void] LessOrEqual([string] $f, [string] $v) {
        $this.Queries.Add($f + "<=" + $v.ToString())
    }

    [void] IsSame([string] $s, [string] $f) {
        $this.Queries.Add($s + "SAMEAS" + $f)
    }

    [void] IsDifferent([string] $s, [string] $f) {
        $this.Queries.Add($s + "NSAMEAS" + $f)
    }

    [void] Contains([string] $f, [string] $v) {
        $this.Queries.Add($f + "LIKE" + $v)
    }

    [void] DoesNotContain([string] $f, [string] $v) {
        $this.Queries.Add($f + "NOT LIKE" + $v)
    }

    [void] Equals([string] $f, [string] $v) {
        $this.Queries.Add($f + "=" + $v)
    }

    [void] NotEqual([string] $f, [string] $v) {
        $this.Queries.Add($f + "!=" + $v)
    }
      
    [void] IsEmpty([string] $f) {
        $this.Queries.Add($f + "ISEMPTY")
    }

    [void] IsNotEmpty([string] $f) {
        $this.Queries.Add($f + "ISNOTEMPTY")
    }

    [void] StartsWith([string] $f, [string] $v) {
        $this.Queries.Add($f + "STARTSWITH" + $v)
    }

    [void] EndsWith([string] $f, [string] $v) {
        $this.Queries.Add($f + "ENDSWITH" + $v)
    }

    [void] IsOneOf([string] $f, [System.Collections.ArrayList] $a) {
        $this.Queries.Add($f + "IN" + ($a -join ','))
    }
}

class ServiceNowDataSet : System.Collections.ArrayList {
    ServiceNowDataSet() : base() {  }
    
    [Int32] AddRecord([ServiceNowData]$d) {
        return $this.Add($d)
    }
    
    [string] ToLoadXml([string]$t) {
        $d = (Get-Date)
        $dateStr = ($d.Year.ToString() + "-" + $d.Month.ToString().PadLeft(2,"0") + "-" + $d.Day.ToString().PadLeft(2,"0") + " " + $d.Hour.ToString().PadLeft(2,"0") + ":" + $d.Minute.ToString().PadLeft(2,"0") + ":" + $d.Second.ToString().PadLeft(2,"0"))
        $body = "<?xml version=`"1.0`" encoding=`"UTF-8`"?><unload unload_date=`"$dateStr`">"
        
        $this | ForEach-Object {
            $body += "<$t action=`"INSERT_OR_UPDATE`">"
            
            $row = $_
            $row | Get-Member -MemberType NoteProperty | ForEach-Object {
                $fieldName = $_.Name
                $fieldValue = $row.$fieldName
                if ($fieldValue.ToString().Length -gt 0) {
                    if ($fieldValue -match '[<>=]') {
                        $body += "<$fieldName><![CDATA[$fieldValue]]></$fieldName>"
                    }
                    else {
                        $body += "<$fieldName>$fieldValue</$fieldName>"
                    }
                }
                else {
                    $body += "<$fieldName/>"
                }
            }
            
            $body += "</$t>"
        }
        
        $body += "</unload>"
        
        return ([xml]($body)).OuterXml
    }
    
    static [ServiceNowDataSet] FromXml([xml]$x) {
        $returnValue = [ServiceNowDataSet]::new()

        ($x.ChildNodes | Where-Object { $_.GetType().Name -eq "XmlElement" }).ChildNodes | ForEach-Object {
            $d = [ServiceNowData]::new()
            
            $row = $_
            
            $row.ChildNodes | ForEach-Object {
                $fieldName = $_.Name
                $d.SetValue($fieldName,$row.$fieldName)
            }
            
            $returnValue.Add($d)
        }
        
        return $returnValue
    }
    
    static [ServiceNowDataSet] FromPSObj([Object[]]$ob) {
        $returnValue = [ServiceNowDataSet]::new()
        
        $ob | ForEach-Object {
            $row = [ServiceNowData]::FromPSObj($_)
            $returnValue.AddRecord($row)
        }
        
        return $returnValue
    }
}

class ServiceNowData {
    ServiceNowData() { }

    [bool] FieldExists([string]$f) {
        return [bool]($this | Get-Member -MemberType NoteProperty -Name $f)
    }
    
    [void] SetValue([string] $f, [string] $v) {
        if ($this.FieldExists($f)) {
            $this.$f = $v
        }
        else {
            $this | Add-Member -MemberType NoteProperty -Name $f -Value $v
        }
    }
    
    [string] ToLoadXml([string]$t) {
        $d = (Get-Date)
        $dateStr = ($d.Year.ToString() + "-" + $d.Month.ToString().PadLeft(2,"0") + "-" + $d.Day.ToString().PadLeft(2,"0") + " " + $d.Hour.ToString().PadLeft(2,"0") + ":" + $d.Minute.ToString().PadLeft(2,"0") + ":" + $d.Second.ToString().PadLeft(2,"0"))
        $body = "<?xml version=`"1.0`" encoding=`"UTF-8`"?><unload unload_date=`"$dateStr`">"
        
        $body += "<$t action=`"INSERT_OR_UPDATE`">"
        
        $this | Get-Member -MemberType NoteProperty | ForEach-Object {
            $fieldName = $_.Name
            $fieldValue = $this."$fieldName"
                
            if ($fieldValue.ToString().Length -gt 0) {
              if ($fieldValue -match '[<>=]') {
                $body += "<$fieldName><![CDATA[$fieldValue]]></$fieldName>"
              }
              else {
                $body += "<$fieldName>$fieldValue</$fieldName>"
              }
            }
            else {
              $body += "<$fieldName/>"
            }
        }
        
        $body += "</$t></unload>"
        
        return ([xml]($body)).OuterXml
    }
    
    [string] ToString() {
        $ar = [System.Collections.ArrayList]::new()
        
        $this | Get-Member -MemberType NoteProperty | ForEach-Object {
            $fieldName = $_.Name
            $ar.Add($fieldName + "=" + $this."$fieldName")
        }
        
        return ($ar -join '&')
    }
    
    static [ServiceNowData] FromPSObj([pscustomobject] $o) {
        $ob = [ServiceNowData]::new()

        $o | Get-Member -MemberType NoteProperty | ForEach-Object {
            $f = $_.Name
            $v = $o."$f"
            $ob.SetValue($f, $v)
        }

        return $ob
    }
}

class ServiceNowFieldList : System.Collections.ArrayList {
    ServiceNowFieldList() : base() { }
    
    [string] GetCommaList() {
        return ($this -join ',')
    }
}

class ServiceNowOperation {
    [ServiceNowConnection] $Connection
    [string] $Table
    [Microsoft.PowerShell.Commands.WebRequestMethod] $HttpMethod

    ServiceNowOperation([ServiceNowConnection] $c, [string] $t) {
        $this.Connection = $c
        $this.Table = $t
    }
}

class ServiceNowWriteOperation : ServiceNowOperation {
    [ServiceNowData] $Data
    [System.Collections.Hashtable] $Headers

    ServiceNowWriteOperation([ServiceNowConnection] $c, [string] $t) : base($c, $t) {
        $this.Data = [ServiceNowData]::new()
        $this.Headers['Accept'] = "application/json"
        $this.Headers['Content-Type'] = "application/json"
    }
}

class ServiceNowAttachment : ServiceNowWriteOperation {
    [string] $SysId
    [System.IO.FileInfo] $FileObject
    [string] $ImageField
    [System.Collections.Hashtable] $ContentTypeMap = @{
        ".jpg"  = "image/jpeg"
        ".jpeg" = "image/jpeg"
        ".png"  = "image/png"
    }

    # Used for attaching a file to a record
    ServiceNowAttachment([ServiceNowConnection] $c, [string] $t, [string] $s, [string] $p) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
        $this.SysId = $s
        $this.FileObject = (Get-Item $p)
        $this.ImageField = $null

        $this.Headers['Content-Type'] = "application/octet-stream"
    }

    # Used for attaching a file to an image field on a record
    ServiceNowAttachment([ServiceNowConnection] $c, [string] $t, [string] $s, [string] $p, [string] $i) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
        $this.SysId = $s
        $this.FileObject = (Get-Item $p)
        $this.ImageField = $i
        $this.Table = ("ZZ_YY" + $t)

        $this.Headers['Content-Type'] = "application/octet-stream"
    }

    [byte[]] GetFileBytes() {
        return [System.IO.File]::ReadAllBytes($this.FileObject.FullName)
    }

    [string] GetRequestUrl() {
        return ("https://" + $this.Connection.Hostname + "/api/now/attachment/file?table_name=" + $this.Table + "&table_sys_id=" + $this.SysId + "&file_name=" + $this.FileObject.Name)
    }

    [pscustomobject] Invoke() {
        $data = $this.GetFileBytes()
        $url = $this.GetRequestUrl()

        $resp = (Invoke-WebRequest -Headers $this.Headers -Body $data -Method $this.HttpMethod -Credential $this.Connection.Credentials $url)

        $returnValue = [pscustomobject]@{
            Upload = $false
        }

        if (($resp.StatusCode - 200) -lt 100) {
            $returnValue.Upload = $true

            if ($this.ImageField) {
                $returnValue | Add-Member -MemberType NoteProperty -Name Field -Value $false

                $attachmentId = ($resp.Content | ConvertFrom-Json).result.sys_id
                $u = [ServiceNowUpdate]::new($this.Connection, $this.Table, $attachmentId)
                $u.Data.SetValue('file_name', $this.ImageField)
                $u.Data.SetValue('table_name', $this.Table)
                $u.Data.SetValue('content_type', $this.ContentTypeMap[$this.FileObject.Extension])
      
                $result = $u.Invoke()

                $returnValue.Field = [bool]$result
            }
        }

        return $returnValue
    }
}

class ServiceNowInsert : ServiceNowWriteOperation {
    ServiceNowInsert([ServiceNowConnection] $c, [string] $t) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
    }
  
    [ServiceNowData] Invoke() {
        $postJson = ($this.Data | ConvertTo-Json)

        $resp = (Invoke-WebRequest -Headers $this.Headers -Body $postJson -Method $this.HttpMethod -Credential $this.Connection.Credentials ("https://" + $this.Connection.Hostname + "/api/now/table/" + $this.Table))

        $returnValue = $null

        if (($resp.StatusCode - 200) -lt 100) {
            $result = ($resp.Content | ConvertFrom-Json).result
            $returnValue = [ServiceNowData]::FromPSObj($result)
        }
    
        return $returnValue
    }
}

class ServiceNowUpdate : ServiceNowWriteOperation {
    [string] $SysId

    ServiceNowUpdate([ServiceNowConnection] $c, [string] $t, [string] $s) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Put
        $this.SysId = $s
    }

    [pscustomobject] Invoke() {
        $postJson = ($this.Data | ConvertTo-Json)
        $resp = (Invoke-WebRequest -Headers $this.Headers -Body $postJson -Method $this.HttpMethod -Credential $this.Connection.Credentials ("https://" + $this.Connection.Hostname + "/api/now/table/" + $this.Table + "/" + $this.SysId))
      
        $returnValue = $null

        if (($resp.StatusCode - 200) -lt 100) {
            $result = ($resp.Content | ConvertFrom-Json).result
            $returnValue = [ServiceNowData]::FromPSObj($result)
        }
    
        return $returnValue
    }
}

class ServiceNowQuery : ServiceNowOperation {
    [int32] $Limit
    [int32] $Offset
    [ServiceNowQueryBuilder] $Query
    [ServiceNowFieldList] $Fields

    ServiceNowQuery([ServiceNowConnection] $c, [string] $t) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        $this.Query = [ServiceNowQueryBuilder]::new()
        $this.Limit = 0
        $this.Offset = 0
        $this.Fields = [ServiceNowFieldList]::new()
    }

    [string] GetUIUrl() {
        return ('https://' + $this.Connection.Hostname + '/' + $this.Table + '_list.do?sysparm_query=' + ([System.Uri]::EscapeDataString($this.Query.Get())))
    }
    
    [xml] GetXMLData([string]$c) {
        $data = [xml]$null
        
        $resp = (Invoke-WebRequest -Uri ($this.GetUIUrl() + '&XML') -Headers @{ "Cookie"=$c})
        if (($resp.StatusCode - 200) -lt 100) {
            $data = [xml]($resp.Content)
        }
        
        return $data
    }

    [string] GetRequestUrl() {
        $paramAr = [System.Collections.ArrayList]::new()

        if ($this.Query.Get().Length -gt 0) {
            $paramAr.Add("sysparm_query=" + $this.Query.Get())
        }

        if ($this.Limit -gt 0) {
            $paramAr.Add("sysparm_limit=" + $this.Limit.ToString())
        }

        if ($this.Offset -gt 0) {
            $paramAr.Add("sysparm_offset=" + $this.Offset.ToString())
        }

        if ($this.Fields.Count -gt 0) {
            $paramAr.Add("sysparm_fields=" + ($this.Fields.GetCommaList()))
        }

        return [uri]::EscapeUriString('https://' + $this.Connection.Hostname + "/api/now/table/" + $this.Table + "`?" + ($paramAr -join "&"))
    }

    [Object[]] Invoke() {
        $url = $this.GetRequestUrl()
    
        $resp = (Invoke-WebRequest -Method $this.HttpMethod -Credential $this.Connection.Credentials $url)

        $returnValue = [System.Collections.ArrayList]::new()

        if (($resp.StatusCode - 200) -lt 100) {
            ($resp.Content | ConvertFrom-Json).result | ForEach-Object {
                $returnValue.Add([ServiceNowData]::FromPSObject($_))
            }
        }

        return $returnValue
    }
}

class ServiceNowStats : ServiceNowOperation {
    [ServiceNowQueryBuilder] $Query
    [ServiceNowFieldList] $Average
    [ServiceNowFieldList] $Minimum
    [ServiceNowFieldList] $Maximum
    [ServiceNowFieldList] $Sum
    [bool] $Count
    
    ServiceNowStats([ServiceNowConnection] $c, [string] $t) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        $this.Query = [ServiceNowQueryBuilder]::new()
        $this.Average = [ServiceNowFieldList]::new()
        $this.Minimum = [ServiceNowFieldList]::new()
        $this.Maximum = [ServiceNowFieldList]::new()
        $this.Sum = [ServiceNowFieldList]::new()
        $this.Count = $false
    }
    
    [string] GetRequestUrl() {
        $paramAr = [System.Collections.ArrayList]::new()

        if ($this.Query.Get().Length -gt 0) {
            $paramAr.Add("sysparm_query=" + $this.Query.Get())
        }

        if ($this.Average.Count -gt 0) {
            $paramAr.Add("sysparm_avg_fields=" + $this.Average.GetCommaList())
        }

        if ($this.Minimum.Count -gt 0) {
            $paramAr.Add("sysparm_min_fields=" + $this.Minimum.GetCommaList())
        }

        if ($this.Maximum.Count -gt 0) {
            $paramAr.Add("sysparm_max_fields=" + ($this.Maximum.GetCommaList()))
        }
        
        if ($this.Sum.Count -gt 0) {
            $paramAr.Add("sysparm_sum_fields=" + ($this.Sum.GetCommaList()))
        }

        return [uri]::EscapeUriString('https://' + $this.Connection.Hostname + "/api/now/stats/" + $this.Table + "`?" + ($paramAr -join "&"))
    }
    
    [pscustomobject] Invoke() {
        $url = $this.GetRequestUrl()
    
        $resp = (Invoke-WebRequest -Method $this.HttpMethod -Credential $this.Connection.Credentials $url)

        $returnValue = [pscustomobject]@{ }

        if (($resp.StatusCode - 200) -lt 100) {
            $returnValue = ($resp.Content | ConvertFrom-Json).result.stats
        }

        return $returnValue
    }
}