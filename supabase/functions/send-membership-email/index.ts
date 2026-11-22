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

const escapeHtml = (value: string) => value.replace(/[&<>"']/g, (c) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
}[c]!));

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { user_id } = await req.json();
    if (typeof user_id !== "string" || !/^[0-9a-f-]{36}$/i.test(user_id)) {
      return json({ error: "Invalid request." }, 400);
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const resendKey = Deno.env.get("RESEND_API_KEY");
    const from = Deno.env.get("RESEND_FROM_EMAIL");
    if (!resendKey || !from) return json({ error: "Email service is not fully configured. Set RESEND_API_KEY and RESEND_FROM_EMAIL." }, 503);

    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
    const { data: authData, error: authError } = await admin.auth.admin.getUserById(user_id);
    const recipient = authData?.user?.email;
    if (authError || !recipient) return json({ error: "Member account not found." }, 404);

    const { data: member, error: memberError } = await admin
      .from("vss_members")
      .select("full_name,membership_no,status")
      .eq("user_id", user_id)
      .maybeSingle();
    if (memberError || !member?.membership_no) return json({ error: "Membership record is not ready yet. Please try again shortly." }, 404);

    // A short cooldown prevents repeated public calls from flooding the member's inbox.
    const { data: recent } = await admin
      .from("vss_email_send_log")
      .select("last_sent_at")
      .eq("user_id", user_id)
      .maybeSingle();
    if (recent?.last_sent_at && Date.now() - new Date(recent.last_sent_at).getTime() < 60_000) {
      return json({ sent: true, throttled: true });
    }

    const { error: logError } = await admin.from("vss_email_send_log").upsert({
      user_id,
      last_sent_at: new Date().toISOString(),
    });
    if (logError) return json({ error: "Unable to prepare membership email." }, 500);

    const name = escapeHtml(member.full_name || "VSS Member");
    const id = escapeHtml(member.membership_no);
    const html = `<!doctype html><html><body style="margin:0;background:#f4f5f7;font-family:Arial,sans-serif;color:#17191d;padding:28px 12px"><div style="max-width:560px;margin:auto;background:#fff;border-radius:16px;overflow:hidden"><div style="background:#a91020;color:#fff;padding:24px"><div style="font-size:20px;font-weight:700">VSS COMMUNITY</div><div style="font-size:11px;letter-spacing:2px;margin-top:5px">VIDYARTHI SEVA SANGATHAN · CGIT RAIPUR</div></div><div style="padding:28px"><p>Hello ${name},</p><p>Your VSS membership account has been created. Keep this membership ID safe; you can use it with your password to sign in to the member portal.</p><div style="background:#fff3f3;border:1px solid #f0c9cc;border-radius:12px;padding:18px;text-align:center;margin:22px 0"><div style="font-size:11px;color:#7a2028;letter-spacing:1px">YOUR MEMBERSHIP ID</div><div style="font-size:22px;font-weight:800;letter-spacing:1px;margin-top:8px">${id}</div></div><p><a href="https://acnoabhay.github.io/Vss/membership.html" style="display:inline-block;background:#a91020;color:#fff;text-decoration:none;padding:12px 18px;border-radius:8px;font-weight:700">Open VSS Member Portal</a></p><p style="font-size:12px;color:#737985">If you did not create this account, you can ignore this email.</p></div></div></body></html>`;

    const mailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Authorization": `Bearer ${resendKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from,
        to: [recipient],
        subject: "Your VSS Membership ID",
        html,
      }),
    });

    if (!mailResponse.ok) {
      const detail = await mailResponse.text();
      console.error("Resend delivery failed:", detail);
      return json({ error: "Membership email could not be sent. Please contact VSS support." }, 502);
    }

    return json({ sent: true });
  } catch (error) {
    console.error("send-membership-email error:", error);
    return json({ error: "Unable to send membership email right now." }, 500);
  }
});
