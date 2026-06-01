####################
#
# ServiceNow Table API Library for Powershell
#
# Importing module
#
#       Import-Module \path\to\servicenow.psm1
#
#       $sn = Get-ServiceNowClasses
#
#       # NOTE:  all forthcoming examples will use $sn for object instantiation
#
# Usage:
#  1. Define connection (host, user, password):
#
#        
#        $conn = $sn.ServiceNowConnection::new("hostname","username",secure-string-password)
#
#        If you have a clear text password in a variable, do this (requires utility.psm1):
#
#               Import-Module \path\to\utility.psm1
#               $util = Get-UtilityClasses
#               $secpass = $util.SecurePassword::SetPasswordFromText($clearTextPass)
#               $conn = $sn.ServiceNowConnection::new("hostname","username",$secpass.Password)
#
#  2. If performing an query, setup the query object:
#
#        $query = $sn.ServiceNowQuery::new($conn,'incident')
#        $query.Query.Equals("active","true")
#        $query.Query.IsOneOf("state",@(4,5))
#        
#        $descrQuery = $sn.ServiceNowQueryBuilder::new()
#        $descrQuery.MakeOr()
#        $descrQuery.Contains("short_description","linux")
#        $descrQuery.Contains("short_description","windows")
#
#        $query.Append($descrQuery)
#
#        $ $query.Query.Get() => active=true^stateIN4,5^short_descriptionLIKElinux^ORshort_descriptionLIKEwindows
#
#        # ServiceNowQueryBuilder instance objects contain the following query operations:
#
#        #     GreaterOrEqual(field,value)
#        #     LessOrEqual(field,value)
#        #     IsSame(field,otherfield)
#        #     IsDifferent(field,otherfield)
#        #     Contains(field,value)
#        #     DoesNotContain(field,value)
#        #     Equals(field,value)
#        #     NotEqual(field,value)
#        #     IsEmpty(field)
#        #     IsNotEmpty(field)
#        #     StartsWith(field,value)
#        #     EndsWith(field,value)
#        #     IsOneOf(field,array)
#
#     If performing an insert, setup the insert object:
#
#        $insert = $sn.ServiceNowInsert::new($conn,'incident')
#        $insert.Data.SetValue("short_description","This is the new short description")
#        $insert.Data.SetValue("caller_id","abel.tuter@example.com")
#        # add other fields as necessary
#
#     If performing an update, setup the update object:
#
#        $update = $sn.ServiceNowUpdate::new($conn,'incident')
#        $update.Data.SetValue("short_description","This is the new short description")
#        $update.Data.SetValue("caller_id","abel.tuter@example.com")
#
#  3. If preforming a query, run the following command:
#
#        $resp = $query.Invoke()

#        # $resp is an array of PSCustomObjects (or $null if unsucessful)
#        # To convert a PSCustomObject instance to a ServiceNowData instance, do this:
#
#                $snowdata = $sn.ServiceNowData::FromPSObject($psobject)
#
#      If performing an update, run the following command:
#
#        $resp = $update.invoke()
#
#        # $resp contains a single PSCustomObject for the updated record (or $null if unsuccessful)
#
#      Performing an insert uses the same syntax and returns PSCustomObject the same as updating:
#
#        $resp = $insert.invoke()
#        
#        $resp = (Invoke-ServiceNowUpdate -Connection $conn -Table "incident" -SysId "87976f52ea9130aaccfa3b5ebbd3f109" -Data $data)
#
# Attach a file to a record:
#      
#  1. If uploading an attachment to a record, provide the connection object, table name, sys_id of the record, and location of the file:
#
#        $attachment = $sn.ServiceNowAttachment::new($conn,"incident","9fcdf552b56cc8b90a47364e48e84018","c:\folder\file.doc")
#        $success = $attach.invoke()
#
#        # Boolean value $success.Upload reflects upload success
#
#  2. If uploading an attachment to an image field on a record, provide the connection object, table name, sys_id of the record, location of the file, and image field name:
#
#        $attachment = $sn.ServiceNowAttachment::new($conn,"incident","9fcdf552b56cc8b90a47364e48e84018","c:\folder\file.doc","product_image")
#        $success = $attach.invoke()
#
#        # Boolean value $success.Upload reflects upload success and $success.Field reflects image field value update
#
####################

class ServiceNowConnection {
    [string] $Hostname
    [pscredential] $Credentials

    ServiceNowConnection($h, $u, $p) {
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

    [void] Append($q) {
        $this.Queries.Add($q.Get())
    }

    [void] GreaterOrEqual($f, $v) {
        $this.Queries.Add($f + ">=" + $v.ToString())
    }

    [void] LessOrEqual($f, $v) {
        $this.Queries.Add($f + "<=" + $v.ToString())
    }

    [void] IsSame($s, $f) {
        $this.Queries.Add($s + "SAMEAS" + $f)
    }

    [void] IsDifferent($s, $f) {
        $this.Queries.Add($s + "NSAMEAS" + $f)
    }

    [void] Contains($f, $v) {
        $this.Queries.Add($f + "LIKE" + $v)
    }

    [void] DoesNotContain($f, $v) {
        $this.Queries.Add($f + "NOT LIKE" + $v)
    }

    [void] Equals($f, $v) {
        $this.Queries.Add($f + "=" + $v)
    }

    [void] NotEqual($f, $v) {
        $this.Queries.Add($f + "!=" + $v)
    }
      
    [void] IsEmpty($f) {
        $this.Queries.Add($f + "ISEMPTY")
    }

    [void] IsNotEmpty($f) {
        $this.Queries.Add($f + "ISNOTEMPTY")
    }

    [void] StartsWith($f, $v) {
        $this.Queries.Add($f + "STARTSWITH" + $v)
    }

    [void] EndsWith($f, $v) {
        $this.Queries.Add($f + "ENDSWITH" + $v)
    }

    [void] IsOneOf($f, $a) {
        $this.Queries.Add($f + "IN" + (([System.Collections.ArrayList]$a) -join ','))
    }
}

class ServiceNowData {
    ServiceNowData() {  }

    [void] SetValue($f, $v) {
        $Exists = (Get-Member -InputObject $this -Name $f)

        if ($Exists) {
            $this."$f" = $v
        }
        else {
            $this | Add-Member -MemberType NoteProperty -Name $f -Value $v
        }
    }
  
    static [ServiceNowData] FromPSObj($o) {
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
}

class ServiceNowOperation {
    [ServiceNowConnection] $Connection
    [string] $Table
    [Microsoft.PowerShell.Commands.WebRequestMethod] $HttpMethod

    ServiceNowOperation($c, $t) {
        $this.Connection = $c
        $this.Table = $t
    }
}

class ServiceNowWriteOperation : ServiceNowOperation {
    [ServiceNowData] $Data
    [System.Collections.Hashtable] $Headers

    ServiceNowWriteOperation($c, $t) : base($c, $t) {
        $this.Data = [ServiceNowData]::new()
        $this.Headers['Accept'] = "application/json"
        $this.Headers['Content-Type'] = "application/json"
    }

    ServiceNowWriteOperation($c, $t, $d) : base($c, $t) {
        $this.Data = $d
        $this.Headers['Accept'] = "application/json"
        $this.Headers['Content-Type'] = "application/json"
    }
}

class ServiceNowAttachment : ServiceNowWriteOperation {
    [string] $SysId
    [System.IO.FileInfo] $FileObject
    [string] $ImageField
    [System.Collections.Hashtable] $ContenTypeMap = @{
        ".jpg"  = "image/jpeg"
        ".jpeg" = "image/jpeg"
        ".png"  = "image/png"
    }

    ServiceNowAttachment($c, $t, $s, $p) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
        $this.SysId = $s
        $this.FileObject = (Get-Item $p)
        $this.ImageField = $null

        $this.Headers['Content-Type'] = "application/octet-stream"
    }

    ServiceNowAttachment($c, $t, $s, $p, $i) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
        $this.SysId = $s
        $this.FilePath = $p
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
                $u.Data.SetValue('content_type', $this.ContenTypeMap[$this.FileObject.Extension])
      
                $result = $u.Invoke()

                $returnValue.Field = [bool]$result
            }
        }

        return $returnValue
    }
}

class ServiceNowInsert : ServiceNowWriteOperation {
    ServiceNowInsert($c, $t) : base($c, $t) {
        $this.HttpMethod = $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
    }
  
    ServiceNowInsert($c, $t, $d) : base($c, $t, $d) {
        $this.HttpMethod = $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
    }

    [ServiceNowData] Invoke() {
        $postJson = ($this.Data.Get() | ConvertTo-Json)

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

    ServiceNowUpdate($c, $t, $s) : base($c, $t) {
        $this.HttpMethod = $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Put
        $this.SysId = $s
    }

    ServiceNowUpdate($c, $t, $s, $d) : base($c, $t, $d) {
        $this.HttpMethod = $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Put
        $this.SysId = $s
    }

    [pscustomobject] Invoke() {
        $postJson = ($this.Data.Get() | ConvertTo-Json)
        $resp = (Invoke-WebRequest -Headers $this.Headers -Body $postJson -Method $this.HttpMethod -Credential $this.Connection.Credentials ("https://" + $this.Connection.Hostname + "/api/now/table/" + $this.Table + "/" + $this.SysId))
      
        $returnValue = $null

        if (($resp.StatusCode - 200) -lt 100) {
            $returnValue = ($resp.Content | ConvertFrom-Json).result
        }
    
        return $returnValue
    }
}

class ServiceNowQuery : ServiceNowOperation {
    [int32] $Limit
    [int32] $Offset
    [ServiceNowQueryBuilder] $Query
    [ServiceNowFieldList] $Fields

    ServiceNowQuery($c, $t) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        $this.Query = [ServiceNowQueryBuilder]::new()
        $this.Limit = 0
        $this.Offset = 0
        $this.Fields = [ServiceNowFieldList]::new()
    }

    ServiceNowQuery($c, $t, $q) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        $this.Query = $q
        $this.Limit = 0
        $this.Offset = 0
        $this.Fields = [ServiceNowFieldList]::new()
    }

    ServiceNowQuery($c, $t, $q, $fl) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        $this.Query = $q
    
        if ($fl.GetType().Name -eq 'Int32') {
            $this.Limit = $fl
            $this.Fields = [System.Collections.ArrayList]::new()
        }
        elseif ($fl.GetType().Name -eq 'ServiceNowFieldList') {
            $this.Limit = 0
            $this.Fields = $fl
        }
        else {
            throw "Error:  4th argument must be 'Int32' or 'ServiceNowFieldList'"
        }
    

        $this.Offset = 0
    }

    ServiceNowQuery($c, $t, $q, $l, $fo) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        $this.Query = $q
        $this.Limit = $l
    
        if ($fo.GetType().Name -eq 'Int32') {
            $this.Offset = $fo
            $this.Fields = [System.Collections.ArrayList]::new()
        }
        elseif ($fo.GetType().Name -eq 'ServiceNowFieldList') {
            $this.Offset = 0
            $this.Fields = $fo
        }
        else {
            throw "Error:  5th argument must be 'Int32' or 'ServiceNowFieldList'"
        }
    }

    ServiceNowQuery($c, $t, $q, $l, $o, $f) : base($c, $t) {
        $this.HttpMethod = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get
        $this.Query = $q
        $this.Limit = $l
        $this.Offset = $o
        $this.Fields = $f
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
            $paramAr.Add("sysparm_fields=" + ($this.Fields -join ','))
        }

        return [uri]::EscapeUriString('https://' + $this.Connection.Hostname + "/api/now/table/" + $this.Table + "`?" + ($paramAr -join "&"))
    }

    [Object[]] Invoke() {
        $url = $this.GetRequestUrl()
    
        $resp = (Invoke-WebRequest -Method $this.HttpMethod -Credential $this.Connection.Credentials $url)

        $returnValue = [pscustomobject]@{ }

        if (($resp.StatusCode - 200) -lt 100) {
            $returnValue = ($resp.Content | ConvertFrom-Json).result
        }

        return $returnValue
    }
}

function Get-ServiceNowClasses() {
    return [pscustomobject]@{
        "ServiceNowConnection"     = [ServiceNowConnection]
        "ServiceNowQueryBuilder"   = [ServiceNowQueryBuilder]
        "ServiceNowData"           = [ServiceNowData]
        "ServiceNowFieldList"      = [ServiceNowFieldList]
        "ServiceNowOperation"      = [ServiceNowOperation]
        "ServiceNowWriteOperation" = [ServiceNowWriteOperation]
        "ServiceNowAttachment"     = [ServiceNowAttachment]
        "ServiceNowInsert"         = [ServiceNowInsert]
        "ServiceNowUpdate"         = [ServiceNowUpdate]
        "ServiceNowQuery"          = [ServiceNowQuery]
    }
}
