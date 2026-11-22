// Supabase Edge Function: vss-member-otp
// Required secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY,
// OTP_FROM_EMAIL (a sender authorised by Resend), OTP_PEPPER (long random secret).
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-api-version, x-supabase-client-platform, x-supabase-client-runtime, x-supabase-client-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
  "Content-Type": "application/json"
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });
const hex = (bytes: Uint8Array) => Array.from(bytes, b => b.toString(16).padStart(2, "0")).join("");
async function digest(value: string) {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))));
}
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);
  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
    const FROM = Deno.env.get("OTP_FROM_EMAIL") || "onboarding@resend.dev";
    const PEPPER = Deno.env.get("OTP_PEPPER")!;
    if (!SUPABASE_URL || !SERVICE_KEY || !RESEND_API_KEY || !PEPPER) {
      return json({ error: "Email verification is not configured yet. Please contact VSS." }, 500);
    }
    const body = await req.json();
    const action = String(body.action || "");
    const membershipNo = String(body.membership_no || "").trim().toUpperCase();
    const email = String(body.email || "").trim().toLowerCase();
    if (!/^VSS\d{5}$/.test(membershipNo) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json({ error: "Enter a valid VSS ID and registered email address." }, 400);
    }
    const base = SUPABASE_URL.replace(/\/$/, "");
    const headers = { apikey: SERVICE_KEY, Authorization: "Bearer " + SERVICE_KEY, "Content-Type": "application/json" };
    const db = async (path: string, init: RequestInit = {}) => {
      const r = await fetch(base + "/rest/v1/" + path, { ...init, headers: { ...headers, ...(init.headers || {}) } });
      const data = await r.json().catch(() => null);
      if (!r.ok) throw new Error(data?.message || data?.hint || "Database request failed.");
      return data;
    };
    if (action === "request") {
      const rows = await db("vss_id_cards?select=membership_no,email&membership_no=eq." + encodeURIComponent(membershipNo) + "&limit=1");
      if (!rows?.length || String(rows[0].email).toLowerCase() !== email) {
        return json({ error: "The VSS ID and registered email do not match." }, 400);
      }
      const recent = await db("vss_member_email_otps?select=last_sent_at&membership_no=eq." + encodeURIComponent(membershipNo) + "&limit=1");
      if (recent?.length && Date.now() - new Date(recent[0].last_sent_at).getTime() < 60000) {
        return json({ error: "Please wait 60 seconds before requesting another OTP." }, 429);
      }
      const otp = String(crypto.getRandomValues(new Uint32Array(1))[0] % 1000000).padStart(6, "0");
      const otpHash = await digest(membershipNo + ":" + email + ":" + otp + ":" + PEPPER);
      await db("vss_member_email_otps?on_conflict=membership_no", {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: JSON.stringify({ membership_no: membershipNo, email, otp_hash: otpHash, expires_at: new Date(Date.now() + 5 * 60000).toISOString(), attempts: 0, last_sent_at: new Date().toISOString() })
      });
      const mail = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: "Bearer " + RESEND_API_KEY, "Content-Type": "application/json" },
        body: JSON.stringify({
          from: FROM, to: [email], subject: "Your VSS Member ID verification code",
          html: "<div style='font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px;color:#17191d'><h2 style='color:#b51220'>VSS Community</h2><p>Your one-time password to access your VSS digital membership card is:</p><div style='font-size:32px;font-weight:800;letter-spacing:8px;padding:16px;background:#f4f5f7;border-radius:10px;text-align:center'>" + otp + "</div><p>This code expires in 5 minutes. Do not share it with anyone.</p><p style='color:#68707b;font-size:12px'>If you did not request this code, you can ignore this email.</p></div>"
        })
      });
      if (!mail.ok) {
        const err = await mail.json().catch(() => ({}));
        // Remove the pending OTP so a failed email send does not lock the member out for 60 seconds.
        await db("vss_member_email_otps?membership_no=eq." + encodeURIComponent(membershipNo), { method: "DELETE" }).catch(() => null);
        throw new Error(err.message || "Email provider could not send the OTP. Check the sender domain configuration.");
      }
      return json({ success: true, message: "OTP sent." });
    }
    if (action === "verify") {
      const otp = String(body.otp || "").trim();
      if (!/^\d{6}$/.test(otp)) return json({ error: "Enter the 6-digit OTP." }, 400);
      const rows = await db("vss_member_email_otps?select=*&membership_no=eq." + encodeURIComponent(membershipNo) + "&limit=1");
      if (!rows?.length || rows[0].email !== email) return json({ error: "Request a new OTP first." }, 400);
      const row = rows[0];
      if (new Date(row.expires_at).getTime() < Date.now()) {
        await db("vss_member_email_otps?membership_no=eq." + encodeURIComponent(membershipNo), { method: "DELETE" });
        return json({ error: "OTP expired. Please request a new one." }, 400);
      }
      if (row.attempts >= 5) return json({ error: "Too many incorrect attempts. Request a new OTP." }, 429);
      const candidate = await digest(membershipNo + ":" + email + ":" + otp + ":" + PEPPER);
      if (candidate !== row.otp_hash) {
        await db("vss_member_email_otps?membership_no=eq." + encodeURIComponent(membershipNo), { method: "PATCH", body: JSON.stringify({ attempts: row.attempts + 1 }) });
        return json({ error: "Incorrect OTP. Please try again." }, 400);
      }
      await db("vss_member_email_otps?membership_no=eq." + encodeURIComponent(membershipNo), { method: "DELETE" });
      const members = await db("vss_id_cards?select=membership_no,full_name,branch,semester,membership_category,photo_url&email=eq." + encodeURIComponent(email) + "&membership_no=eq." + encodeURIComponent(membershipNo) + "&limit=1");
      if (!members?.length) return json({ error: "Member record not found." }, 404);
      return json({ success: true, member: members[0] });
    }
    return json({ error: "Unsupported action." }, 400);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unexpected server error." }, 500);
  }
});
