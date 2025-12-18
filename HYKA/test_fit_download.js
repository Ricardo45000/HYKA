#!/usr/bin/env node

// ============================================================================
// Test FIT File Download for Existing Activity
// ============================================================================
// Run: node test_fit_download.js 21194868043
// ============================================================================

const https = require('https');
const http = require('http');

const SUPABASE_URL = 'https://gvfhtiljkybbrbxoyqsq.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w';

const ACTIVITY_ID = process.argv[2] || '21194868043';
const GARMIN_USER_ID = 'ae3cd04a-b8d6-4803-b7ed-7213c975c258';

function makeRequest(url, options, data) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const requestOptions = {
      hostname: urlObj.hostname,
      port: urlObj.port || 443,
      path: urlObj.pathname + urlObj.search,
      method: options.method || 'GET',
      headers: {
        ...options.headers,
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`
      }
    };

    const req = https.request(requestOptions, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          resolve({ status: res.statusCode, data: json });
        } catch (e) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });

    req.on('error', reject);
    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

async function main() {
  console.log('============================================================================');
  console.log('TEST FIT FILE DOWNLOAD');
  console.log('============================================================================');
  console.log(`Activity ID: ${ACTIVITY_ID}`);
  console.log('');

  // Step 1: Trigger store function
  console.log('Step 1: Triggering garmin-activity-store to download FIT file...');
  console.log('');

  const payload = {
    garminUserId: GARMIN_USER_ID,
    summary: {
      summaryId: ACTIVITY_ID,
      activityId: ACTIVITY_ID,
      activityName: 'Test Activity',
      activityType: 'running'
    }
  };

  console.log('Payload:');
  console.log(JSON.stringify(payload, null, 2));
  console.log('');

  try {
    const storeResponse = await makeRequest(
      `${SUPABASE_URL}/functions/v1/garmin-activity-store`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' } },
      payload
    );

    console.log('Response:');
    console.log(JSON.stringify(storeResponse.data, null, 2));
    console.log('');

    // Step 2: Wait
    console.log('Waiting 3 seconds...');
    await new Promise(resolve => setTimeout(resolve, 3000));
    console.log('');

    // Step 3: Check if FIT file was downloaded
    console.log('Step 2: Checking if FIT file was downloaded...');
    console.log('');

    const activityResponse = await makeRequest(
      `${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=id,has_fit_file`,
      { method: 'GET' }
    );

    let activityUuid = null;
    let hasFitFile = false;
    
    if (activityResponse.data && activityResponse.data.length > 0) {
      const activity = activityResponse.data[0];
      activityUuid = activity.id;
      hasFitFile = activity.has_fit_file;

      console.log('✅ Activity found in database');
      console.log(`   UUID: ${activityUuid}`);
      console.log(`   Has FIT file: ${hasFitFile}`);
      console.log('');
    } else {
      console.log('⚠️ Activity not found in database. The store function should have created it.');
      console.log('   Checking if it was created...');
      console.log('');
      
      // Wait a bit more and check again
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      const activityResponse2 = await makeRequest(
        `${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=id,has_fit_file`,
        { method: 'GET' }
      );
      
      if (activityResponse2.data && activityResponse2.data.length > 0) {
        const activity = activityResponse2.data[0];
        activityUuid = activity.id;
        hasFitFile = activity.has_fit_file;
        
        console.log('✅ Activity now exists in database');
        console.log(`   UUID: ${activityUuid}`);
        console.log(`   Has FIT file: ${hasFitFile}`);
        console.log('');
      } else {
        console.log('❌ Activity still not found after store function call');
        console.log('');
        console.log('Possible reasons:');
        console.log('  1. Invalid activity ID');
        console.log('  2. No Garmin connection for this user');
        console.log('  3. Store function failed (check logs)');
        console.log('');
        console.log('Store function response was:');
        console.log(JSON.stringify(storeResponse.data, null, 2));
        return;
      }
    }
    
    // Check FIT file
    if (activityUuid) {
      const fitFileResponse = await makeRequest(
        `${SUPABASE_URL}/rest/v1/garmin_fit_files?activity_id=eq.${activityUuid}&select=id,file_size_bytes,created_at`,
        { method: 'GET' }
      );

      const fitFiles = Array.isArray(fitFileResponse.data) ? fitFileResponse.data : [];
      const fitCount = fitFiles.length;

      if (fitCount > 0) {
        const fitSize = fitFiles[0].file_size_bytes || 0;
        console.log('✅ FIT file found!');
        console.log(`   Size: ${fitSize} bytes`);
        console.log('');

        // Check samples
        const samplesResponse = await makeRequest(
          `${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${activityUuid}&select=id`,
          { method: 'GET' }
        );

        const samples = Array.isArray(samplesResponse.data) ? samplesResponse.data : [];
        const sampleCount = samples.length;

        console.log(`📊 Activity Samples: ${sampleCount}`);

        if (sampleCount === 0) {
          console.log('');
          console.log('⚠️ FIT file exists but no samples extracted yet.');
          console.log('   The FIT processor should run automatically.');
          console.log('   If samples don\'t appear, check the garmin-fit-processor logs.');
        } else {
          console.log('✅ Samples extracted successfully!');
        }
      } else {
        console.log('❌ No FIT file found in database');
        console.log('');
        console.log('Possible reasons:');
        console.log('  1. FIT file not available yet (404 from Garmin)');
        console.log('  2. OAuth token doesn\'t have permission');
        console.log('  3. Activity doesn\'t have a FIT file (manual entry)');
        console.log('');
        console.log('Check the Edge Function logs for details.');
      }
    } else {
      console.log('❌ Activity not found in database');
      console.log('   Make sure the activity ID is correct and the webhook was received.');
    }
  } catch (error) {
    console.error('❌ Error:', error.message);
  }

  console.log('');
  console.log('============================================================================');
}

main();

