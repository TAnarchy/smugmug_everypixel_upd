import requests
import json
from requests_oauthlib import OAuth1Session
import logging



#import http.client
#http.client.HTTPConnection.debuglevel = 1

logging.basicConfig(level=logging.DEBUG)
log = logging.getLogger(__name__)

# Your credentials from the OAuth process
api_key = '{SMUGMUG API Key}'
api_secret = '{SMUGMUG API Secret}'
auth_token = '{SMUTMUG AUTH TOKEN}'
token_secret = '{SMUGMUG TOKEN SECRET}'

# Create a new session with your tokens
smugmug = OAuth1Session(api_key, client_secret=api_secret,
                        resource_owner_key=auth_token, 
                        resource_owner_secret=token_secret)

# Send a request
headers = {'Accept': 'application/json'}
print("\n\n\n\n\n\nBefore sending that request\n\n\n\n")
response = smugmug.get('https://api.smugmug.com/api/v2/image/{ALBUM ID}',headers=headers)

# Convert the response to JSON
data = response.json()

# Print the data
archived_uri=data["Response"]['Image']['ArchivedUri']

#Passing the image to the AI to get a list of keywords
params = {'url': archived_uri, 'num_keywords': 20}

client_id = '{EVERYPIXEL client ID}'
client_secret = '{EVERYPIXEL client secret}'

keywords_json = requests.get('https://api.everypixel.com/v1/keywords', params=params, auth=(client_id, client_secret)).json()
keywords = [item['keyword'] for item in keywords_json['keywords']]
keywords_combined=", ".join(keywords)
print(keywords_combined)

# updating the keywords in Smug
url = 'https://api.smugmug.com/api/v2/image/{ALBUM ID}'
headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json'
}

data = {
    'Keywords': keywords_combined,
}

response2 = smugmug.post('https://api.smugmug.com/api/v2/image/{ALBUM ID-4?_method=PATCH', headers=headers, data=json.dumps(data))
print('Final Status: ', response2.status_code)
#print(response2.text)
