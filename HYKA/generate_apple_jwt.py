#!/usr/bin/env python3
"""
Generate Apple Sign In JWT Client Secret

Usage:
    python3 generate_apple_jwt.py <TEAM_ID> <SERVICE_ID> [KEY_FILE]

Example:
    python3 generate_apple_jwt.py ABC123XYZ com.hyka.signin
"""

import sys
import json
import time
from datetime import datetime, timedelta
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.backends import default_backend
import jwt

# Default values
DEFAULT_KEY_FILE = '/Users/ricardoda-silva/Downloads/AuthKey_GTT69XWZG8.p8'
KEY_ID = 'GTT69XWZG8'

def generate_jwt(team_id, service_id, key_file=DEFAULT_KEY_FILE):
    """Generate JWT client secret for Apple Sign In"""
    
    # Read private key
    try:
        with open(key_file, 'r') as f:
            private_key_pem = f.read()
    except FileNotFoundError:
        print(f'❌ Key file not found: {key_file}')
        sys.exit(1)
    
    # Load private key
    try:
        private_key = serialization.load_pem_private_key(
            private_key_pem.encode(),
            password=None,
            backend=default_backend()
        )
    except Exception as e:
        print(f'❌ Error loading private key: {e}')
        sys.exit(1)
    
    # Create JWT header
    header = {
        'alg': 'ES256',
        'kid': KEY_ID
    }
    
    # Create JWT payload
    now = int(time.time())
    exp = now + (6 * 30 * 24 * 60 * 60)  # 6 months from now
    
    payload = {
        'iss': team_id,
        'iat': now,
        'exp': exp,
        'aud': 'https://appleid.apple.com',
        'sub': service_id
    }
    
    print('🔑 Generating Apple Sign In JWT Client Secret...')
    print('')
    print('Configuration:')
    print(f'   Team ID:    {team_id}')
    print(f'   Service ID: {service_id}')
    print(f'   Key ID:     {KEY_ID}')
    print(f'   Key File:   {key_file}')
    print('')
    
    # Generate JWT
    try:
        token = jwt.encode(
            payload,
            private_key,
            algorithm='ES256',
            headers=header
        )
        
        print('✅ JWT Generated Successfully!')
        print('')
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        print('APPLE SIGN IN CLIENT SECRET (JWT):')
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        print('')
        print(token)
        print('')
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        print('')
        print('📋 JWT Details:')
        print(f'   Issued At:  {datetime.fromtimestamp(now).isoformat()}')
        print(f'   Expires:    {datetime.fromtimestamp(exp).isoformat()}')
        print(f'   Valid for:  6 months')
        print('')
        print('💡 Use this JWT as the "Client Secret" in Supabase Dashboard → Authentication → Providers → Apple')
        print('')
        
        return token
        
    except Exception as e:
        print(f'❌ Error generating JWT: {e}')
        print('')
        print('Make sure:')
        print('  1. The .p8 file is valid')
        print('  2. The Team ID is correct')
        print('  3. The Service ID is correct')
        print('  4. You have PyJWT and cryptography installed:')
        print('     pip3 install PyJWT cryptography')
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('❌ Missing required arguments')
        print('')
        print('Usage: python3 generate_apple_jwt.py <TEAM_ID> <SERVICE_ID> [KEY_FILE]')
        print('')
        print('Example:')
        print('  python3 generate_apple_jwt.py ABC123XYZ com.hyka.signin')
        print('')
        print('Arguments:')
        print('  TEAM_ID    - Your Apple Team ID (found in Apple Developer Portal, top right)')
        print('  SERVICE_ID - Your Service ID for Sign in with Apple')
        print('  KEY_FILE   - Path to .p8 file (optional, defaults to AuthKey_GTT69XWZG8.p8)')
        print('')
        print('Install dependencies:')
        print('  pip3 install PyJWT cryptography')
        sys.exit(1)
    
    team_id = sys.argv[1]
    service_id = sys.argv[2]
    key_file = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_KEY_FILE
    
    generate_jwt(team_id, service_id, key_file)
