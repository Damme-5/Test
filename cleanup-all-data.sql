-- ============================================
-- CLEAN SLATE: Slet alle brugere og data
-- ============================================
-- ADVARSEL: Dette sletter ALT data permanent!
-- Kør kun dette hvis du vil starte helt forfra.
-- ============================================

-- Trin 1: Slet alle organisationer (CASCADE sletter automatisk:
--         members, invitations, cases, tasks, chats, chat_participants, messages)
DELETE FROM organizations;

-- Trin 2: Slet alle brugere fra auth.users
-- BEMÆRK: Dette kræver service_role nøgle eller kørsel via Supabase Dashboard
DELETE FROM auth.users;

-- Bekræft at alt er slettet
SELECT 'organizations' as table_name, COUNT(*) as count FROM organizations
UNION ALL
SELECT 'members', COUNT(*) FROM members
UNION ALL
SELECT 'invitations', COUNT(*) FROM invitations
UNION ALL
SELECT 'cases', COUNT(*) FROM cases
UNION ALL
SELECT 'tasks', COUNT(*) FROM tasks
UNION ALL
SELECT 'chats', COUNT(*) FROM chats
UNION ALL
SELECT 'chat_participants', COUNT(*) FROM chat_participants
UNION ALL
SELECT 'messages', COUNT(*) FROM messages;
