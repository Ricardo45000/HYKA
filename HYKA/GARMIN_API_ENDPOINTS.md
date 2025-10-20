# Garmin API Endpoints Used

## Overview

This document lists all Garmin API endpoints currently used in the HYKA application.

---

## OAuth 2.0 Authentication

### 1. Token Exchange
- **Endpoint:** `https://diauth.garmin.com/di-oauth2-service/oauth/token`
- **Method:** POST
- **Used in:** `garmin-auth-callback`
- **Purpose:** Exchange authorization code for access_token and refresh_token
- **Authentication:** OAuth 2.0 PKCE (client_id + client_secret)

---

## Wellness API (OAuth 2.0)

### 2. Get User ID
- **Endpoint:** `https://apis.garmin.com/wellness-api/rest/user/id`
- **Method:** GET
- **Used in:** `garmin-auth-callback`
- **Purpose:** Fetch Garmin user ID after OAuth
- **Authentication:** OAuth 2.0 Bearer token (access_token)
- **Response:** `{ "userId": "garmin_user_id" }`

### 3. Backfill Activities (Historical Data)
- **Endpoint:** `https://apis.garmin.com/wellness-api/rest/backfill/activities`
- **Method:** GET
- **Used in:** `garmin-activity-backfill`
- **Purpose:** Request historical activity data
- **Authentication:** OAuth 2.0 Bearer token (access_token)
- **Parameters:**
  - `summaryStartTimeInSeconds` (required): UTC timestamp (when data was recorded)
  - `summaryEndTimeInSeconds` (required): UTC timestamp (when data was recorded)
- **Response:** 202 Accepted (async processing)
- **Note:** Maximum 30 days per request

### 4. Activity Callback URLs (from Webhooks)
- **Base URL:** `https://apis.garmin.com/.../pull?token=XYZ` (from webhook callbackUrl)
- **Method:** GET
- **Used in:** `garmin-activity-pull`
- **Purpose:** Fetch activity data using temporary callback URL
- **Authentication:** Temporary token in callbackUrl (provided by Garmin)
- **Endpoints:**
  - `GET callbackUrl` → Activity summary
  - `GET callbackUrl/details` → Activity details (samples)
  - `GET callbackUrl/file` → FIT file (for ultra-runners)

---

## API Endpoints NOT Used (Removed/Deprecated)

### ❌ Removed - Wellness API Polling
- ~~`https://apis.garmin.com/wellness-api/rest/activities`~~ (removed - use backfill instead)
- ~~`https://apis.garmin.com/wellness-api/rest/activityDetails`~~ (removed - use callbackUrl/details instead)
- ~~`https://apis.garmin.com/wellness-api/rest/userMetrics`~~ (removed - use webhooks instead)

### ❌ Removed - Connect API
- ~~`https://connectapi.garmin.com/...`~~ (removed - OAuth 1.0 deprecated)
- ~~`https://connect.garmin.com/...`~~ (removed - web endpoints not needed for mobile)

---

## Summary

### Currently Used Endpoints (3)

1. **OAuth Token Exchange**
   - `https://diauth.garmin.com/di-oauth2-service/oauth/token`
   - Purpose: Get access_token and refresh_token

2. **Get User ID**
   - `https://apis.garmin.com/wellness-api/rest/user/id`
   - Purpose: Get Garmin user ID after OAuth

3. **Backfill Activities**
   - `https://apis.garmin.com/wellness-api/rest/backfill/activities`
   - Purpose: Request historical activity data

### Webhook-Based Data (No Direct API Calls)

- **Activity Data:** Received via webhooks (PING/PUSH)
- **Health Data:** Received via webhooks (User Metrics, Health Snapshot)
- **Permission Changes:** Received via webhooks

All activity and health data is **pushed by Garmin via webhooks**, not pulled by API calls.

---

## Authentication

All Wellness API endpoints use:
- **OAuth 2.0 Bearer token** (access_token from OAuth 2.0 PKCE flow)
- **No Pull Token needed** (Pull Token is only in callbackUrl for webhook data)

---

## Reference

- **OAuth 2.0 PKCE:** https://developerportal.garmin.com/sites/default/files/OAuth2PKCE_1.pdf
- **Activity API 1.2.3:** https://developerportal.garmin.com/sites/default/files/Activity_API-1.2.3_0.pdf

