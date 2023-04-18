# Input bindings are passed in via param block.
param([string]$QueueItem, $TriggerMetadata)

# Write out the queue message and metadata to the information log.
Write-Host "PowerShell queue trigger function processed work item: $QueueItem"
$URL = $QueueItem.tolower()
$Table = Get-CIPPTable -TableName "cache$url"
$fullUrl = "https://graph.microsoft.com/beta/$url"
Get-AzDataTableEntity @Table | Remove-AzDataTableEntity @table

$RawGraphRequest = Get-Tenants | ForEach-Object -Parallel { 
    $domainName = $_.defaultDomainName
    Import-Module '.\GraphHelper.psm1'
    try {
        Write-Host $using:fullUrl
        New-GraphGetRequest -uri $using:fullUrl -tenantid $_.defaultDomainName -ErrorAction Stop | Select-Object *, @{l = 'tenant'; e = { $domainName } }, @{l = 'CippStatus'; e = { "Good" } }

    }
    catch {
        [PSCustomObject]@{
            Tenant     = $domainName
            CippStatus = "Could not connect to tenant. $($_.Exception.message)"
        }
    } 
}
foreach ($Request in $RawGraphRequest) {
    if (!$Request.Status) {
        $Json = ConvertTo-Json -Compress -InputObject $request
    }
    $GraphRequest = [PSCustomObject]@{
        Tenant       = [string]$Request.tenant
        RowKey       = [string](New-Guid)
        PartitionKey = [string]$URL
        Data         = [string]$Json

    }
    Write-Host "$fullUrl - $($GraphRequest.tenant)"
    Add-AzDataTableEntity @Table -Entity $GraphRequest -Force | Out-Null
}

$QueueKey = (Get-CippQueue | Where-Object -Property Name -EQ $url | Select-Object -Last 1).RowKey
Update-CippQueueEntry -RowKey $QueueKey -Status "Completed"