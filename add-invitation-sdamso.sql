-- Script til at tilføje Sdamso@live.dk til Carescore organisationen
-- Kør dette i Supabase SQL Editor

-- Indsæt invitation for Sdamso@live.dk til Carescore organisationen
INSERT INTO invitations (organization_id, email, invited_by)
SELECT
    o.id as organization_id,
    'Sdamso@live.dk' as email,
    o.created_by as invited_by
FROM organizations o
WHERE LOWER(o.name) = LOWER('Carescore')
ON CONFLICT (organization_id, email) DO NOTHING;

-- Verificer at invitationen blev tilføjet
SELECT
    i.id as invitation_id,
    o.name as organization_name,
    i.email,
    i.created_at
FROM invitations i
JOIN organizations o ON i.organization_id = o.id
WHERE i.email = 'Sdamso@live.dk';
