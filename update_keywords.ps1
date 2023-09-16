#Get Oauth function
function Get-OAuthAuthorization {
   
    [CmdletBinding(DefaultParameterSetName = 'None')]
    [OutputType('System.Management.Automation.PSCustomObject')]
    param (
        [Parameter(Mandatory)]
        [string]$HttpEndPoint,
        [Parameter(Mandatory)]
        [ValidateSet('POST', 'GET', 'PATCH')]
        [string]$HttpVerb,
        [Parameter(Mandatory)]
        [hashtable]$ApiParameters
    )
    
  
    
    process {
        try {
            ## Generate a random 32-byte string. I'm using the current time (in seconds) and appending 5 chars to the end to get to 32 bytes
            ## Base64 allows for an '=' but Twitter does not. If this is found, replace it with some alphanumeric character
            #$OauthNonce = "113121055705985524811689868899"
            Write-Verbose "Generated Oauth none string '$OauthNonce'"
            
            ## Find the total seconds since 1/1/1970 (epoch time)
            $EpochTimeNow = [System.DateTime]::UtcNow - [System.DateTime]::ParseExact("01/01/1970", "dd/MM/yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
            Write-Verbose "Generated epoch time '$EpochTimeNow'"
            $OauthTimestamp = [System.Convert]::ToInt64($EpochTimeNow.TotalSeconds).ToString();
            Write-Verbose "Generated Oauth timestamp '$OauthTimestamp'"
            $randon_nonce=(Get-Random -Maximum ([int]::MaxValue))
            ## Build the signature
            $configData = Get-Content -Path "SmugConfig.json" | ConvertFrom-Json
			$SignatureBase = "$([System.Uri]::EscapeDataString($HttpEndPoint))&"
            $SignatureParams = @{
                'oauth_consumer_key'     =  $configData.oauth_consumer_key
                'oauth_nonce'            =$randon_nonce # Random nonce
                'oauth_signature_method' = 'HMAC-SHA1';
                'oauth_timestamp'        =  [int][double]::Parse((Get-Date -UFormat %s)) # Unix timestamp
                'oauth_token'            = $configData.oauth_token
                'oauth_version'          = '1.0';
            }
            
            $AuthorizationParams = $SignatureParams.Clone()

            
            ## Add API-specific params to the signature
            foreach ($Param in $ApiParameters.GetEnumerator()) {
                $SignatureParams[$Param.Key] = $Param.Value
            }
			
            
            ## Create a string called $SignatureBase that joins all URL encoded 'Key=Value' elements with a &
            ## Remove the URL encoded & at the end and prepend the necessary 'POST&' verb to the front
            $SignatureParams.GetEnumerator() | Sort-Object -Property Name | foreach { $SignatureBase += [System.Uri]::EscapeDataString("$($_.Key)=$($_.Value)&") }
            $SignatureBase = $SignatureBase.TrimEnd('%26')
			 $SignatureBase = "$HttpVerb&" + $SignatureBase
			if ($HttpVerb -ne "GET") {
				 $SignatureBase = $SignatureBase -replace "{ALBUM ID}-4&oauth_consumer_key", "{ALBUM ID}-4&_method%3DPATCH%26oauth_consumer_key"
			}
            Write-Verbose "Base signature generated '$SignatureBase'"
            
            ## Create the hashed string from the base signature
			
            $SignatureKey = [System.Uri]::EscapeDataString($configData.api_secret) + "&" + [System.Uri]::EscapeDataString($configData.token_secret);
            
            $hmacsha1 = new-object System.Security.Cryptography.HMACSHA1;
            $hmacsha1.Key = [System.Text.Encoding]::ASCII.GetBytes($SignatureKey);

            $OauthSignature = [System.Convert]::ToBase64String($hmacsha1.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($SignatureBase)));
            Write-Verbose "Using signature '$OauthSignature'"
            
            ## Build the authorization headers. This is joining all of the 'Key=Value' elements again
            ## and only URL encoding the Values this time while including non-URL encoded double quotes around each value
            $AuthorizationParams.Add('oauth_signature', $OauthSignature)    
            $AuthorizationString = 'OAuth '
            $AuthorizationParams.GetEnumerator() | Sort-Object -Property name | foreach { $AuthorizationString += $_.Key + '="' + [System.Uri]::EscapeDataString($_.Value) + '", ' }
            $AuthorizationString = $AuthorizationString.TrimEnd(', ')
            Write-Verbose "Using authorization string '$AuthorizationString'"

            $AuthorizationString
            
        } catch {
            Write-Error $_.Exception.Message
        }
    }
}

$configData = Get-Content -Path "SmugConfig.json" | ConvertFrom-Json
#Auth params and initial request
$oauth_consumer_key = $configData.oauth_consumer_key
$oauth_token=$configData.oauth_token
$oauth_signature_method = 'HMAC-SHA1'
$api_secret =$configData.api_secret
$token_secret =$configData.token_secret
$oauth_version = '1.0'
$httpMethod='GET'
$url = 'https://api.smugmug.com/api/v2/image/{ALBUM ID}-4'


$parameters = "oauth_consumer_key=$oauth_consumer_key&oauth_signature_method=HMAC-SHA1&oauth_token=$oauth_token&oauth_version=1.0"

$hashTable = @{}

# Split the query string into key-value pairs
$pairs = $parameters -split "&"

# For each pair, split it into key and value, and add to the hashtable
foreach($pair in $pairs) {
    $keyValue = $pair -split "="
    $hashTable[$keyValue[0]] = $keyValue[1]
}


$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$oathString2=Get-OAuthAuthorization -HttpVerb $httpMethod -HttpEndPoint $url -ApiParameters $hashTable


$headers.Add("Authorization", $oathString2)
`
$headers.Add("Accept", "application/json")
$response = Invoke-WebRequest -Uri $url -Headers $headers


$jsonResponse = $response.Content | ConvertFrom-Json
$archivedUri=$jsonResponse.Response.Image.ArchivedUri

#Request for Keywords
Write-Host `r`

Write-Host "ARCHIVED URI: "
Write-Host $archivedUri
Write-Host `r`

$params = @{
    'url' = $archivedUri
    'num_keywords' = 20
}

# Define your client id and secret
$client_id = $configData.client_id
$client_secret = $configData.client_secret

$encodedAuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $client_id,$client_secret)))

$headers = @{
    "Authorization" = "Basic $encodedAuthInfo"
}

$keywords_json = Invoke-RestMethod -Uri 'https://api.everypixel.com/v1/keywords' -Method Get -Headers $headers -Body $params
# Extract the keywords
$keywords = $keywords_json.keywords.keyword

# Join the keywords into a single string
$keywords_combined = $keywords -join ", "

# Print the keywords
Write-Host $keywords_combined

# Update Keywords
$httpMethod='POST'
$url = 'https://api.smugmug.com/api/v2/image/{ALBUM ID}-4'


$oauthParams2 = @{
    oauth_token = $oauth_token
    oauth_signature_method = $oauth_signature_method
    oauth_timestamp = $oauth_timestamp
    oauth_version = $oauth_version
    oauth_signature =Get-OAuthAuthorization -HttpVerb $httpMethod -HttpEndPoint $url -ApiParameters $hashTable
}

$body = @{
    Keywords = $keywords_combined
} | ConvertTo-Json

$oauthString3 =Get-OAuthAuthorization -HttpVerb $httpMethod -HttpEndPoint $url -ApiParameters $hashTable


$headers2 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"


$headers2.Add("Authorization", $oauthString3)

$headers2.Add("Accept", "application/json")


$url = 'https://api.smugmug.com/api/v2/image/F6qBW8x-4?_method=PATCH'
$response3 = Invoke-WebRequest -Uri $url -Method $httpMethod -Body $body -Headers $headers2 -ContentType "application/json"



