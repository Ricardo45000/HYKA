-- ============================================================================
-- Create GPX Files Storage Bucket
-- ============================================================================
-- This script creates a Supabase Storage bucket for GPX files
-- Run this in your Supabase SQL Editor
-- ============================================================================

-- Create the storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'gpx-files',
  'gpx-files',
  true, -- Public bucket (files can be accessed via public URL)
  52428800, -- 50 MB file size limit
  ARRAY['application/gpx+xml', 'application/xml', 'text/xml'] -- Allowed MIME types
)
ON CONFLICT (id) DO NOTHING;

-- Drop existing policies if they exist (for re-running this script)
DROP POLICY IF EXISTS "Users can upload their own GPX files" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own GPX files" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own GPX files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own GPX files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload GPX files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can read GPX files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update GPX files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete GPX files" ON storage.objects;

-- Set up RLS policies for the bucket
-- Since the app controls the path structure and validates user ownership at the application level,
-- we allow authenticated users to upload/read/update/delete any file in the bucket.
-- The app-level validation ensures users can only access their own files.

-- Allow authenticated users to upload files (app validates ownership via userId parameter)
CREATE POLICY "Authenticated users can upload GPX files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'gpx-files');

-- Allow authenticated users to read files (app validates ownership)
CREATE POLICY "Authenticated users can read GPX files"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'gpx-files');

-- Allow authenticated users to update files (app validates ownership)
CREATE POLICY "Authenticated users can update GPX files"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'gpx-files');

-- Allow authenticated users to delete files (app validates ownership)
CREATE POLICY "Authenticated users can delete GPX files"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'gpx-files');

-- ============================================================================
-- Verification
-- ============================================================================
-- Run this to verify the bucket was created:
-- SELECT * FROM storage.buckets WHERE id = 'gpx-files';
-- ============================================================================

