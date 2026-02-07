import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get the authorization header to verify the admin user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    // Create Supabase client with service role for admin operations
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Create Supabase client with user's token to verify they're an admin
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader }
        }
      }
    )

    // Get the current user
    const { data: { user: adminUser }, error: userError } = await supabaseUser.auth.getUser()
    if (userError || !adminUser) {
      throw new Error('Unauthorized: Could not verify user')
    }

    // Parse request body
    const { email, password, display_name, organization_id } = await req.json()

    if (!email || !password || !organization_id) {
      throw new Error('Missing required fields: email, password, organization_id')
    }

    // Verify the requesting user is an admin in the organization
    const { data: adminMember, error: adminError } = await supabaseAdmin
      .from('members')
      .select('role')
      .eq('organization_id', organization_id)
      .eq('user_id', adminUser.id)
      .single()

    if (adminError || !adminMember || adminMember.role !== 'admin') {
      throw new Error('Unauthorized: Only admins can create members')
    }

    // Check if user already exists
    const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers()
    const existingUser = existingUsers?.users?.find(u => u.email?.toLowerCase() === email.toLowerCase())

    let newUserId: string

    if (existingUser) {
      // User already exists, just add them to the organization
      newUserId = existingUser.id
    } else {
      // Create the new user with admin API
      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email: email,
        password: password,
        email_confirm: true, // Auto-confirm email
        user_metadata: {
          display_name: display_name || email
        }
      })

      if (createError) {
        throw new Error(`Could not create user: ${createError.message}`)
      }

      newUserId = newUser.user.id
    }

    // Add user to organization as member
    const { error: memberError } = await supabaseAdmin
      .from('members')
      .upsert({
        organization_id: organization_id,
        user_id: newUserId,
        email: email.toLowerCase(),
        role: 'member',
        display_name: display_name || email
      }, {
        onConflict: 'organization_id,user_id'
      })

    if (memberError) {
      throw new Error(`Could not add member: ${memberError.message}`)
    }

    // Delete any pending invitation for this email
    await supabaseAdmin
      .from('invitations')
      .delete()
      .eq('organization_id', organization_id)
      .ilike('email', email)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Member created successfully',
        user_id: newUserId
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})
