#!/bin/bash

# Script to show all calculations for a specific user
USER_ID="84b13928-a931-4841-9289-bf2ab30cb07d"
SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDc2NjI1OCwiZXhwIjoyMDc2MzQyMjU4fQ.jP0v7Xp6q_YPY2mdC0kiFfQM6xHWGZ2ty9fk7zmOcXs"

echo "=============================================================================="
echo "CALCULATIONS FOR USER: $USER_ID"
echo "=============================================================================="
echo ""

# 1. User Profile
echo "1. USER PROFILE"
echo "------------------------------------------------------------------------------"
curl -s "${SUPABASE_URL}/rest/v1/profiles?id=eq.${USER_ID}&select=*" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" | jq '.'
echo ""

# 2. Race Plans
echo "2. RACE PLANS"
echo "------------------------------------------------------------------------------"
curl -s "${SUPABASE_URL}/rest/v1/race_plans?user_id=eq.${USER_ID}&select=*" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" | jq '.'
echo ""

# 3. Race Plan Segments (with calculated metrics)
echo "3. RACE PLAN SEGMENTS (Calculated Metrics)"
echo "------------------------------------------------------------------------------"
RACE_PLAN_IDS=$(curl -s "${SUPABASE_URL}/rest/v1/race_plans?user_id=eq.${USER_ID}&select=id" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" | jq -r '.[].id')

for PLAN_ID in $RACE_PLAN_IDS; do
  echo "  Race Plan ID: $PLAN_ID"
  curl -s "${SUPABASE_URL}/rest/v1/race_plan_segments?race_plan_id=eq.${PLAN_ID}&select=*&order=index" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "Content-Type: application/json" | jq '.'
  echo ""
done

# 4. Track Points (for elevation calculations)
echo "4. TRACK POINTS (Elevation Calculations)"
echo "------------------------------------------------------------------------------"
for PLAN_ID in $RACE_PLAN_IDS; do
  echo "  Race Plan ID: $PLAN_ID"
  TRACK_COUNT=$(curl -s "${SUPABASE_URL}/rest/v1/race_plan_track_points?race_plan_id=eq.${PLAN_ID}&select=id" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "Content-Type: application/json" | jq '. | length')
  
  echo "    Total Track Points: $TRACK_COUNT"
  
  # Get first, middle, and last points for elevation calculation
  FIRST=$(curl -s "${SUPABASE_URL}/rest/v1/race_plan_track_points?race_plan_id=eq.${PLAN_ID}&select=ele,dist_from_start&order=dist_from_start&limit=1" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "Content-Type: application/json" | jq '.[0]')
  
  LAST=$(curl -s "${SUPABASE_URL}/rest/v1/race_plan_track_points?race_plan_id=eq.${PLAN_ID}&select=ele,dist_from_start&order=dist_from_start.desc&limit=1" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "Content-Type: application/json" | jq '.[0]')
  
  echo "    First Point: $FIRST"
  echo "    Last Point: $LAST"
  
  if [ "$TRACK_COUNT" -gt 0 ]; then
    TOTAL_DIST=$(echo "$LAST" | jq -r '.dist_from_start')
    TOTAL_DIST_KM=$(echo "$TOTAL_DIST / 1000" | bc -l)
    echo "    Total Distance: ${TOTAL_DIST_KM} km"
  fi
  echo ""
done

# 5. Activities/Workouts
echo "5. ACTIVITIES/WORKOUTS (Pace Calculations)"
echo "------------------------------------------------------------------------------"
curl -s "${SUPABASE_URL}/rest/v1/unified_activities?user_id=eq.${USER_ID}&select=*&order=start_date.desc&limit=10" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" | jq '.[] | {
    activity_name,
    distance_meters,
    elapsed_time,
    pace_calc: (if .distance_meters > 0 and .elapsed_time > 0 then (.elapsed_time / 60) / (.distance_meters / 1000) else null end),
    pace_min_per_km: (if .distance_meters > 0 and .elapsed_time > 0 then ((.elapsed_time / 60) / (.distance_meters / 1000) | floor) else null end),
    pace_sec_per_km: (if .distance_meters > 0 and .elapsed_time > 0 then (((.elapsed_time / 60) / (.distance_meters / 1000) % 1) * 60 | round) else null end),
    average_heart_rate,
    start_date
  }'
echo ""

# 6. Health Metrics (Fitness Age Calculations)
echo "6. HEALTH METRICS (Fitness Age Calculations)"
echo "------------------------------------------------------------------------------"
curl -s "${SUPABASE_URL}/rest/v1/health_metrics?user_id=eq.${USER_ID}&select=*&order=date.desc&limit=5" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" | jq '.[] | {
    date,
    vo2_max,
    age_years,
    fitness_age,
    fitness_age_calc: (if .vo2_max and .age_years then 
      (let vo2 = .vo2_max | tonumber;
           age = .age_years | tonumber;
           adjustment = (vo2 - 40.0) * -0.8;
           estimated = (age + adjustment) | if . < 18 then 18 else . end) 
      else null end),
    resting_heart_rate,
    weight_kg
  }'
echo ""

# 7. Fuel Events
echo "7. FUEL EVENTS (Nutrition Calculations)"
echo "------------------------------------------------------------------------------"
for PLAN_ID in $RACE_PLAN_IDS; do
  echo "  Race Plan ID: $PLAN_ID"
  curl -s "${SUPABASE_URL}/rest/v1/fuel_events?race_plan_id=eq.${PLAN_ID}&select=*&order=minute" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "Content-Type: application/json" | jq '.'
  echo ""
done

echo "=============================================================================="
echo "CALCULATION SUMMARY"
echo "=============================================================================="
echo ""
echo "Key Calculations Performed:"
echo "  1. Segment Metrics: Distance, Elevation Gain/Loss, Estimated Time, HR"
echo "  2. Pace Calculations: minutes/km from distance and elapsed time"
echo "  3. Elevation Gain: Cumulative sum of positive elevation changes"
echo "  4. Fitness Age: VO2 Max adjusted age calculation"
echo "  5. Fuel Timing: Based on race segments and pace"
echo ""

