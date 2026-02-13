-- ============================================
-- FIX: Tillad organisation-skaberen at blive første admin
-- ============================================
-- Kør dette i Supabase SQL Editor

-- Denne policy tillader at triggeren kan tilføje opretteren som admin
-- når en ny organisation oprettes

CREATE POLICY "Creator becomes initial admin" ON members
    FOR INSERT WITH CHECK (
        user_id = auth.uid() AND
        organization_id IN (
            SELECT id FROM organizations WHERE created_by = auth.uid()
        )
    );
