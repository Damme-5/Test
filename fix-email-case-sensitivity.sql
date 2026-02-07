-- Fix case-insensitive email matching for invitations
-- Run this in Supabase SQL Editor to update the existing policy

-- Drop the existing policy
DROP POLICY IF EXISTS "Users can view invitations for their orgs" ON invitations;

-- Create the updated policy with case-insensitive email matching
CREATE POLICY "Users can view invitations for their orgs" ON invitations
    FOR SELECT USING (
        organization_id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
        OR LOWER(email) = LOWER((SELECT email FROM auth.users WHERE id = auth.uid()))
    );

-- Verify the policy was created
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'invitations';
