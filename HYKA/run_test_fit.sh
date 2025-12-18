#!/bin/bash

# Quick test command
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-store" \
  -H "Content-Type: application/json" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w" \
  -d '{
    "garminUserId": "ae3cd04a-b8d6-4803-b7ed-7213c975c258",
    "summary": {
      "summaryId": "21194868043",
      "activityId": "21194868043",
      "activityName": "Test Activity",
      "activityType": "running"
    }
  }' | jq '.'

