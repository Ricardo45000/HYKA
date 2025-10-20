#!/bin/bash

# Minimal Garmin OAuth 1.0a test - exactly as Garmin expects
python3 << 'PYEOF'
import hmac, hashlib, base64, urllib.parse, time, uuid, subprocess

CONSUMER_KEY = "695055f8-9786-4fda-a3a7-f7c2e88382f0"
CONSUMER_SECRET = "0Bn115Wfjb9RrWvHIro3PB2Sfg0Wq2VTzXiT/yuQ1+Q"
CALLBACK_URL = "https://hyka.app/garmin/callback"

METHOD = "POST"
BASE_URL = "https://connectapi.garmin.com/oauth-service/oauth/request_token"
TIMESTAMP = str(int(time.time()))
NONCE = uuid.uuid4().hex

print("=" * 70)
print("GARMIN OAUTH 1.0a - MINIMAL TEST")
print("=" * 70)
print(f"Consumer Key: {CONSUMER_KEY}")
print(f"Timestamp: {TIMESTAMP}")
print(f"Nonce: {NONCE}")
print()

# Build parameter string (encode BOTH keys and values per OAuth spec)
params = [
    ("oauth_callback", CALLBACK_URL),
    ("oauth_consumer_key", CONSUMER_KEY),
    ("oauth_nonce", NONCE),
    ("oauth_signature_method", "HMAC-SHA1"),
    ("oauth_timestamp", TIMESTAMP),
    ("oauth_version", "1.0")
]

# Sort and encode
param_string = "&".join([
    f"{urllib.parse.quote(k, safe='')}={urllib.parse.quote(v, safe='')}"
    for k, v in sorted(params)
])

print(f"Parameter string: {param_string}")
print()

# Build signature base string
signature_base = (
    f"{METHOD}&"
    f"{urllib.parse.quote(BASE_URL, safe='')}&"
    f"{urllib.parse.quote(param_string, safe='')}"
)

print(f"Signature base: {signature_base[:200]}...")
print()

# Signing key (ENCODED secrets per OAuth spec)
signing_key = f"{urllib.parse.quote(CONSUMER_SECRET, safe='')}&"
print(f"Signing key: {signing_key[:50]}...")
print()

# Generate signature
signature = base64.b64encode(
    hmac.new(
        signing_key.encode('utf-8'),
        signature_base.encode('utf-8'),
        hashlib.sha1
    ).digest()
).decode('utf-8')

print(f"Signature: {signature}")
print()

# Build Authorization header
auth_params = [
    ("oauth_callback", CALLBACK_URL),
    ("oauth_consumer_key", CONSUMER_KEY),
    ("oauth_nonce", NONCE),
    ("oauth_signature", signature),
    ("oauth_signature_method", "HMAC-SHA1"),
    ("oauth_timestamp", TIMESTAMP),
    ("oauth_version", "1.0")
]

auth_header = "OAuth " + ", ".join([
    f'{k}="{urllib.parse.quote(v, safe="")}"'
    for k, v in sorted(auth_params)
])

encoded_callback = urllib.parse.quote(CALLBACK_URL, safe="")

print("=" * 70)
print("CURL COMMAND:")
print("=" * 70)
print()
print(f"curl -X POST '{BASE_URL}' \\")
print(f"  -H 'Authorization: {auth_header}' \\")
print(f"  -H 'Content-Type: application/x-www-form-urlencoded' \\")
print(f"  -d 'oauth_callback={encoded_callback}'")
print()

# Execute
print("=" * 70)
print("EXECUTING REQUEST...")
print("=" * 70)
print()

result = subprocess.run(
    ['curl', '-X', 'POST', BASE_URL,
     '-H', f'Authorization: {auth_header}',
     '-H', 'Content-Type: application/x-www-form-urlencoded',
     '-d', f'oauth_callback={encoded_callback}',
     '-v'],
    capture_output=True,
    text=True
)

print(result.stdout)
if result.stderr:
    print("\nVerbose output:")
    print(result.stderr[-1000:])  # Last 1000 chars

if 'oauth_token' in result.stdout:
    print("\n✅ SUCCESS! Credentials are valid!")
elif 'Invalid nonce' in result.stdout or 'Invalid' in result.stdout:
    print("\n❌ CREDENTIALS INVALID")
    print("\nACTION REQUIRED:")
    print("1. Go to https://developer.garmin.com/")
    print("2. Verify Consumer Key and Secret match EXACTLY")
    print("3. Verify callback URL is registered: https://hyka.app/garmin/callback")
    print("4. Ensure application is approved/active")

PYEOF

