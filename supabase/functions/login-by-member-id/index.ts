import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { membership_no, password } = await req.json();
    const memberNo = String(membership_no ?? "").trim().toUpperCase();
    if (!/^VSS-CGIT-\\d{4}-\\d{4,}$/.test(memberNo) || typeof password !== "string" || password.length < 1) {
      return json({ error: "Invalid membership ID or password." }, 400);
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

    const { data: member, error: memberError } = await admin
      .from("vss_members")
      .select("user_id,status")
      .eq("membership_no", memberNo)
      .maybeSingle();

    // Use one generic error so callers cannot enumerate registered membership IDs.
    if (memberError || !member || member.status !== "approved") {
      return json({ error: "Invalid membership ID or password." }, 401);
    }

    const { data: authData, error: userError } = await admin.auth.admin.getUserById(member.user_id);
    const email = authData?.user?.email;
    if (userError || !email) return json({ error: "Invalid membership ID or password." }, 401);

    const authClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data, error } = await authClient.auth.signInWithPassword({ email, password });
    if (error || !data.session) return json({ error: "Invalid membership ID or password." }, 401);

    return json({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      token_type: data.session.token_type,
      expires_in: data.session.expires_in,
      expires_at: data.session.expires_at,
    });
  } catch {
    return json({ error: "Unable to sign in right now. Please try again." }, 500);
  }
});
