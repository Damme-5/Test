-- Partner Hub Database Schema
-- Run this in Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Organizations table
CREATE TABLE organizations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Organization members
CREATE TABLE members (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    display_name TEXT,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(organization_id, user_id)
);

-- Invitations
CREATE TABLE invitations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    invited_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(organization_id, email)
);

-- Cases
CREATE TABLE cases (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'progress', 'closed')),
    priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
    assigned_to UUID REFERENCES auth.users(id),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tasks
CREATE TABLE tasks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    case_id UUID REFERENCES cases(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    period TEXT DEFAULT 'daily' CHECK (period IN ('daily', 'weekly', 'monthly')),
    deadline DATE,
    assigned_to UUID REFERENCES auth.users(id),
    completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    completed_by UUID REFERENCES auth.users(id),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chats
CREATE TABLE chats (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT DEFAULT 'group' CHECK (type IN ('direct', 'group')),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chat participants
CREATE TABLE chat_participants (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    chat_id UUID REFERENCES chats(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(chat_id, user_id)
);

-- Messages
CREATE TABLE messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    chat_id UUID REFERENCES chats(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Organizations: users can see orgs they're members of
CREATE POLICY "Users can view their organizations" ON organizations
    FOR SELECT USING (
        id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can create organizations" ON organizations
    FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Members: users can see members of their orgs
CREATE POLICY "Users can view members of their orgs" ON members
    FOR SELECT USING (
        organization_id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
    );

CREATE POLICY "Admins can add members" ON members
    FOR INSERT WITH CHECK (
        organization_id IN (
            SELECT organization_id FROM members
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Allow users to add themselves as members when they have a pending invitation
CREATE POLICY "Users can join via invitation" ON members
    FOR INSERT WITH CHECK (
        user_id = auth.uid() AND
        organization_id IN (
            SELECT organization_id FROM invitations
            WHERE email = (SELECT email FROM auth.users WHERE id = auth.uid())
        )
    );

CREATE POLICY "Admins can update members" ON members
    FOR UPDATE USING (
        organization_id IN (
            SELECT organization_id FROM members
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can delete members" ON members
    FOR DELETE USING (
        organization_id IN (
            SELECT organization_id FROM members
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Invitations
CREATE POLICY "Users can view invitations for their orgs" ON invitations
    FOR SELECT USING (
        organization_id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
        OR LOWER(email) = LOWER((SELECT email FROM auth.users WHERE id = auth.uid()))
    );

CREATE POLICY "Admins can create invitations" ON invitations
    FOR INSERT WITH CHECK (
        organization_id IN (
            SELECT organization_id FROM members
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can delete invitations" ON invitations
    FOR DELETE USING (
        organization_id IN (
            SELECT organization_id FROM members
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Cases: users can see cases in their orgs
CREATE POLICY "Users can view cases in their orgs" ON cases
    FOR SELECT USING (
        organization_id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can create cases in their orgs" ON cases
    FOR INSERT WITH CHECK (
        organization_id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can update cases in their orgs" ON cases
    FOR UPDATE USING (
        organization_id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
    );

CREATE POLICY "Admins can delete cases" ON cases
    FOR DELETE USING (
        organization_id IN (
            SELECT organization_id FROM members
            WHERE user_id = auth.uid() AND role = 'admin'
        )
        OR created_by = auth.uid()
    );

-- Tasks
CREATE POLICY "Users can view tasks in their orgs" ON tasks
    FOR SELECT USING (
        organization_id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can create tasks in their orgs" ON tasks
    FOR INSERT WITH CHECK (
        organization_id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can update tasks in their orgs" ON tasks
    FOR UPDATE USING (
        organization_id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can delete their own tasks or admins can delete" ON tasks
    FOR DELETE USING (
        created_by = auth.uid() OR
        organization_id IN (
            SELECT organization_id FROM members
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Chats
CREATE POLICY "Users can view chats they participate in" ON chats
    FOR SELECT USING (
        id IN (SELECT chat_id FROM chat_participants WHERE user_id = auth.uid())
        OR organization_id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can create chats in their orgs" ON chats
    FOR INSERT WITH CHECK (
        organization_id IN (SELECT organization_id FROM members WHERE user_id = auth.uid())
    );

-- Chat participants
CREATE POLICY "Users can view chat participants" ON chat_participants
    FOR SELECT USING (
        chat_id IN (SELECT chat_id FROM chat_participants WHERE user_id = auth.uid())
    );

CREATE POLICY "Chat creators can add participants" ON chat_participants
    FOR INSERT WITH CHECK (
        chat_id IN (SELECT id FROM chats WHERE created_by = auth.uid())
        OR chat_id IN (
            SELECT c.id FROM chats c
            JOIN members m ON c.organization_id = m.organization_id
            WHERE m.user_id = auth.uid()
        )
    );

-- Messages
CREATE POLICY "Users can view messages in their chats" ON messages
    FOR SELECT USING (
        chat_id IN (SELECT chat_id FROM chat_participants WHERE user_id = auth.uid())
        OR chat_id IN (
            SELECT c.id FROM chats c
            JOIN members m ON c.organization_id = m.organization_id
            WHERE m.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can send messages to their chats" ON messages
    FOR INSERT WITH CHECK (
        sender_id = auth.uid() AND (
            chat_id IN (SELECT chat_id FROM chat_participants WHERE user_id = auth.uid())
            OR chat_id IN (
                SELECT c.id FROM chats c
                JOIN members m ON c.organization_id = m.organization_id
                WHERE m.user_id = auth.uid()
            )
        )
    );

-- Enable realtime for messages
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE chats;

-- Function to automatically add creator as admin member
CREATE OR REPLACE FUNCTION handle_new_organization()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO members (organization_id, user_id, email, role, display_name)
    SELECT NEW.id, NEW.created_by, email, 'admin', COALESCE(raw_user_meta_data->>'display_name', email)
    FROM auth.users WHERE id = NEW.created_by;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_organization_created
    AFTER INSERT ON organizations
    FOR EACH ROW EXECUTE FUNCTION handle_new_organization();

-- Function to handle accepted invitations
CREATE OR REPLACE FUNCTION accept_invitation(invitation_id UUID)
RETURNS VOID AS $$
DECLARE
    inv RECORD;
BEGIN
    SELECT * INTO inv FROM invitations WHERE id = invitation_id;

    IF inv IS NULL THEN
        RAISE EXCEPTION 'Invitation not found';
    END IF;

    INSERT INTO members (organization_id, user_id, email, role, display_name)
    SELECT inv.organization_id, auth.uid(), email, 'member', COALESCE(raw_user_meta_data->>'display_name', email)
    FROM auth.users WHERE id = auth.uid()
    ON CONFLICT (organization_id, user_id) DO NOTHING;

    DELETE FROM invitations WHERE id = invitation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
