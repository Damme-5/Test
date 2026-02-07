-- ============================================
-- TRIN 1: Kør dette i Supabase SQL Editor
-- ============================================
-- Denne funktion tillader admins at tilføje medlemmer direkte

-- Opret funktionen admin_add_member
CREATE OR REPLACE FUNCTION admin_add_member(
    p_organization_id UUID,
    p_user_id UUID,
    p_email TEXT,
    p_display_name TEXT
)
RETURNS VOID AS $$
BEGIN
    -- Verificer at den kaldende bruger er admin i organisationen
    IF NOT EXISTS (
        SELECT 1 FROM members
        WHERE organization_id = p_organization_id
        AND user_id = auth.uid()
        AND role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Kun administratorer kan tilføje medlemmer';
    END IF;

    -- Tilføj brugeren som medlem
    INSERT INTO members (organization_id, user_id, email, role, display_name)
    VALUES (p_organization_id, p_user_id, LOWER(p_email), 'member', p_display_name)
    ON CONFLICT (organization_id, user_id) DO UPDATE
    SET display_name = EXCLUDED.display_name;

    -- Slet eventuelle afventende invitationer for denne email
    DELETE FROM invitations
    WHERE organization_id = p_organization_id
    AND LOWER(email) = LOWER(p_email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Giv adgang til funktionen
GRANT EXECUTE ON FUNCTION admin_add_member TO authenticated;
