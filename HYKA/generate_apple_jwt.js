#!/usr/bin/env node

/**
 * Generate Apple Sign In JWT Client Secret
 * 
 * Usage:
 *   node generate_apple_jwt.js <TEAM_ID> <SERVICE_ID>
 * 
 * Example:
 *   node generate_apple_jwt.js ABC123XYZ com.hyka.signin
 */

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// Get arguments
const teamId = process.argv[2];
const serviceId = process.argv[3];
const keyFile = process.argv[4] || '/Users/ricardoda-silva/Downloads/AuthKey_GTT69XWZG8.p8';
const keyId = 'GTT69XWZG8';

if (!teamId || !serviceId) {
  console.error('❌ Missing required arguments');
  console.error('');
  console.error('Usage: node generate_apple_jwt.js <TEAM_ID> <SERVICE_ID> [KEY_FILE]');
  console.error('');
  console.error('Example:');
  console.error('  node generate_apple_jwt.js ABC123XYZ com.hyka.signin');
  console.error('');
  console.error('Arguments:');
  console.error('  TEAM_ID    - Your Apple Team ID (found in Apple Developer Portal, top right)');
  console.error('  SERVICE_ID - Your Service ID for Sign in with Apple');
  console.error('  KEY_FILE   - Path to .p8 file (optional, defaults to AuthKey_GTT69XWZG8.p8)');
  process.exit(1);
}

// Read private key
if (!fs.existsSync(keyFile)) {
  console.error(`❌ Key file not found: ${keyFile}`);
  process.exit(1);
}

const privateKeyContent = fs.readFileSync(keyFile, 'utf8');

// Create JWT header
const header = {
  alg: 'ES256',
  kid: keyId
};

// Create JWT payload
const now = Math.floor(Date.now() / 1000);
const exp = now + (6 * 30 * 24 * 60 * 60); // 6 months from now

const payload = {
  iss: teamId,
  iat: now,
  exp: exp,
  aud: 'https://appleid.apple.com',
  sub: serviceId
};

console.log('🔑 Generating Apple Sign In JWT Client Secret...');
console.log('');
console.log('Configuration:');
console.log(`   Team ID:    ${teamId}`);
console.log(`   Service ID: ${serviceId}`);
console.log(`   Key ID:     ${keyId}`);
console.log(`   Key File:   ${keyFile}`);
console.log('');

// Sign JWT
try {
  const headerBase64 = Buffer.from(JSON.stringify(header)).toString('base64url');
  const payloadBase64 = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const unsignedToken = `${headerBase64}.${payloadBase64}`;

  // Sign with ES256
  const sign = crypto.createSign('SHA256');
  sign.update(unsignedToken);
  sign.end();
  
  const signature = sign.sign({
    key: privateKeyContent,
    dsaEncoding: 'ieee-p1363'
  }, 'base64url');

  const jwt = `${unsignedToken}.${signature}`;

  console.log('✅ JWT Generated Successfully!');
  console.log('');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('APPLE SIGN IN CLIENT SECRET (JWT):');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
  console.log(jwt);
  console.log('');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
  console.log('📋 JWT Details:');
  console.log(`   Issued At:  ${new Date(now * 1000).toISOString()}`);
  console.log(`   Expires:    ${new Date(exp * 1000).toISOString()}`);
  console.log(`   Valid for:  6 months`);
  console.log('');
  console.log('💡 Use this JWT as the "Client Secret" in Supabase Dashboard → Authentication → Providers → Apple');
  console.log('');

} catch (error) {
  console.error('❌ Error generating JWT:', error.message);
  console.error('');
  console.error('Make sure:');
  console.error('  1. The .p8 file is valid');
  console.error('  2. The Team ID is correct');
  console.error('  3. The Service ID is correct');
  process.exit(1);
}
