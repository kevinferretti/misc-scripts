Disable-AzContextAutosave -Scope Process

$AzureContext = (Connect-AzAccount -Identity).context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

Import-Module Microsoft.Graph.Authentication

$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"
$accessToken = $token.Token | ConvertTo-SecureString -AsPlainText -Force
Connect-MgGraph -AccessToken $accessToken

$applications = @()
$nextLink = $null
$expiringCertificatesOutput = ""

do {
    $applicationsPage = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications\$($nextLink -replace '\?', '&')"
    $applications += $applicationsPage.Value
    $nextLink = $applicationsPage.'@odata.nextLink'
} while ($nextLink)

foreach ($application in $applications) {
    $secretsUri = "https://graph.microsoft.com/v1.0/applications/$($application.id)/passwordCredentials"
    $secrets = Invoke-MgGraphRequest -Method GET -Uri $secretsUri

    foreach ($secret in $secrets.value) {
        try {
            $expiryDateTime = [DateTime]$secret.endDateTime
            $expiryDate = $expiryDateTime.Date

            if ($expiryDate -ne $null) {
                $daysUntilExpiry = ($expiryDate - (Get-Date).Date).Days

                if ($daysUntilExpiry -le 90) {
                    $expiringCertificatesOutput += "1. Application Name: $($application.displayName)   \nApplication ID: $($application.id)   \n  Key ID: $($secret.keyId)   \n  Expiry Date: $($expiryDate.ToString("yyyy-MM-dd"))   \n  Days Until Expiry: $daysUntilExpiry\r"
                }
            }
            else {
                throw "Invalid DateTime format"
            }
        }
        catch {
            Write-Output "Error parsing secret expiry date. Skipping secret."
        }
    }
}

Disconnect-MgGraph

if ($expiringCertificatesOutput -ne "") {
    $NotificationBody = @"
    {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "text": "$expiringCertificatesOutput",
        "title": "Some app registration client secrets will be expiring in the next 90 days",
   } 
"@
    Write-Output $NotificationBody
    $TargetChannelURI = "<webhook>"
    Invoke-RestMethod -uri $TargetChannelURI -Method Post -body $NotificationBody -ContentType 'application/json'
}
