// Test notification script
// Distance: 30.5 km, Pace: 3:37 m/km

const SUPABASE_URL = "https://gvfhtiljkybbrbxoyqsq.supabase.co";
const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/garmin-activity-notify`;
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w";

// Test values
const distanceKm = 30.5;
const distanceMeters = distanceKm * 1000;
// Pace: 3:37 m/km = 3 minutes 37 seconds = 217 seconds per km
const paceSecondsPerKm = 217;
const durationSeconds = Math.round(distanceKm * paceSecondsPerKm);

// Get user_id from command line argument
const userId = process.argv[2];

if (!userId) {
  console.error("Usage: node test_notification.js <user_id>");
  console.error("Example: node test_notification.js 123e4567-e89b-12d3-a456-426614174000");
  process.exit(1);
}

const activityId = crypto.randomUUID();

const payload = {
  user_id: userId,
  activity_id: activityId,
  activity_name: "Test Run",
  activity_type: "Running",
  distance_meters: distanceMeters,
  duration_seconds: durationSeconds
};

console.log("Test Notification Parameters:");
console.log(`  Distance: ${distanceKm} km (${distanceMeters} meters)`);
console.log(`  Pace: 3:37 m/km (${paceSecondsPerKm} seconds per km)`);
console.log(`  Duration: ${durationSeconds} seconds (${Math.round(durationSeconds / 60)} minutes)`);
console.log(`  User ID: ${userId}`);
console.log(`  Activity ID: ${activityId}`);
console.log("\nSending notification...\n");

fetch(FUNCTION_URL, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "apikey": SUPABASE_ANON_KEY,
    "Authorization": `Bearer ${SUPABASE_ANON_KEY}`
  },
  body: JSON.stringify(payload)
})
  .then(response => response.json())
  .then(data => {
    console.log("Response:", JSON.stringify(data, null, 2));
  })
  .catch(error => {
    console.error("Error:", error);
  });
