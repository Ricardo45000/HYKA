#!/bin/bash

# Test notification with:
# Distance: 30.5 km
# Pace: 3:37 m/km (3 minutes 37 seconds per kilometer)

# Calculate values
DISTANCE_KM=30.5
DISTANCE_METERS=30500
# Pace: 3:37 m/km = 3 minutes 37 seconds = 217 seconds per km
PACE_SECONDS_PER_KM=217
DURATION_SECONDS=$(echo "$DISTANCE_KM * $PACE_SECONDS_PER_KM" | bc | cut -d. -f1)

echo "Test Notification Parameters:"
echo "  Distance: ${DISTANCE_KM} km (${DISTANCE_METERS} meters)"
echo "  Pace: 3:37 m/km (${PACE_SECONDS_PER_KM} seconds per km)"
echo "  Duration: ${DURATION_SECONDS} seconds ($(echo "scale=1; $DURATION_SECONDS / 60" | bc) minutes)"
echo ""
echo "Please provide your user_id (UUID) to test the notification:"
read -p "User ID: " USER_ID

if [ -z "$USER_ID" ]; then
  echo "Error: User ID is required"
  exit 1
fi

# Generate a test activity ID
ACTIVITY_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

echo ""
echo "Sending test notification via Supabase CLI..."
echo ""

# Use Supabase CLI to invoke the function
supabase functions invoke garmin-activity-notify \
  --body "{
    \"user_id\": \"${USER_ID}\",
    \"activity_id\": \"${ACTIVITY_ID}\",
    \"activity_name\": \"Test Run\",
    \"activity_type\": \"Running\",
    \"distance_meters\": ${DISTANCE_METERS},
    \"duration_seconds\": ${DURATION_SECONDS}
  }"

echo ""
echo "Done!"
