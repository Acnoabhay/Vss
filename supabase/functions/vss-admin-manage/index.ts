// VSS departmental admin account manager.
// Deploy: supabase functions deploy vss-admin-manage
// Secret required: SUPABASE_SERVICE_ROLE_KEY (never expose it in browser code).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization") || "";
  if (!url || !serviceKey || !authHeader.startsWith("Bearer ")) {
    return json({ error: "Server configuration or authentication is missing." }, 500);
  }

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const token = authHeader.slice(7);
  const { data: authData, error: authError } = await admin.auth.getUser(token);
  const actor = authData?.user;
  if (authError || !actor || (actor.email || "").toLowerCase() !== "info.vsscommunity@gmail.com") {
    return json({ error: "Only the VSS Main Admin can manage departmental accounts." }, 403);
  }

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Invalid request body." }, 400); }
  const action = String(body.action || "");
  if (action === "create") {
    const fullName = String(body.full_name || "").trim();
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");
    const department = String(body.department || "");
    const designation = String(body.designation || "").trim() || "Department Administrator";
    if (fullName.length < 2 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
        password.length < 12 || designation.length > 100 || !["academic", "technical", "administration", "organizing"].includes(department)) {
      return json({ error: "Provide a name, valid email, department and a password of at least 12 characters." }, 400);
    }
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email, password, email_confirm: true, user_metadata: { full_name: fullName }
    });
    if (createError || !created.user) return json({ error: createError?.message || "Could not create account." }, 400);
    const { error: rowError } = await admin.from("vss_admin_accounts").insert({
      user_id: created.user.id, full_name: fullName, email, department, designation, is_active: true, created_by: actor.id
    });
    if (rowError) {
      await admin.auth.admin.deleteUser(created.user.id);
      return json({ error: rowError.message }, 400);
    }
    const defaults: Record<string,string[]> = {
      academic: ["dashboard.view","notices.view","notices.create","notices.edit","notices.publish","notices.delete","events.view","events.manage","events.publish"],
      technical: ["dashboard.view","gallery.view","gallery.upload","gallery.publish","gallery.delete"],
      administration: ["dashboard.view","members.view","members.manage","members.verify","users.manage","corecards.review"],
      organizing: ["dashboard.view","events.view","events.manage","events.publish","gallery.view","gallery.upload","gallery.publish"]
    };
    const { error: permissionError } = await admin.from("vss_admin_permissions").insert(
      (defaults[department] || []).map(permission_key => ({ user_id: created.user!.id, permission_key, granted_by: actor.id }))
    );
    if (permissionError) {
      await admin.auth.admin.deleteUser(created.user.id);
      return json({ error: permissionError.message }, 400);
    }
    return json({ success: true, message: "Departmental admin account created with starter permissions." });
  }

  if (action === "update_profile") {
    const userId = String(body.user_id || "");
    const department = String(body.department || "");
    const designation = String(body.designation || "").trim();
    if (!userId || !["academic", "technical", "administration", "organizing"].includes(department) ||
        designation.length < 2 || designation.length > 100) {
      return json({ error: "Choose a valid department and enter a designation between 2 and 100 characters." }, 400);
    }
    const { data: target, error: lookupError } = await admin.from("vss_admin_accounts")
      .select("user_id").eq("user_id", userId).maybeSingle();
    if (lookupError || !target) return json({ error: lookupError?.message || "Admin account not found." }, 404);
    const { error } = await admin.from("vss_admin_accounts")
      .update({ department, designation, updated_at: new Date().toISOString() }).eq("user_id", userId);
    if (error) return json({ error: error.message }, 400);
    return json({ success: true, message: "Department and designation updated." });
  }

  if (action === "set_permissions") {
    const userId = String(body.user_id || "");
    const requested = Array.isArray(body.permissions) ? body.permissions.map((v: unknown) => String(v)) : [];
    const allowed = new Set([
      "dashboard.view","members.view","members.manage","members.verify","users.manage",
      "notices.view","notices.create","notices.edit","notices.publish","notices.delete",
      "events.view","events.manage","events.publish",
      "gallery.view","gallery.upload","gallery.publish","gallery.delete","corecards.review"
    ]);
    if (!userId || requested.some((key: string) => !allowed.has(key))) {
      return json({ error: "Invalid administrator or permission selection." }, 400);
    }
    const { data: target, error: lookupError } = await admin.from("vss_admin_accounts")
      .select("user_id").eq("user_id", userId).maybeSingle();
    if (lookupError || !target) return json({ error: lookupError?.message || "Admin account not found." }, 404);
    const { error: deleteError } = await admin.from("vss_admin_permissions").delete().eq("user_id", userId);
    if (deleteError) return json({ error: deleteError.message }, 400);
    if (requested.length) {
      const { error: insertError } = await admin.from("vss_admin_permissions").insert(
        [...new Set(requested)].map(permission_key => ({ user_id: userId, permission_key, granted_by: actor.id }))
      );
      if (insertError) return json({ error: insertError.message }, 400);
    }
    return json({ success: true, message: "Administrator permissions updated." });
  }

  if (action === "set_active") {
    const userId = String(body.user_id || "");
    const isActive = body.is_active === true;
    if (!userId) return json({ error: "Missing admin account ID." }, 400);
    const { data: target, error: lookupError } = await admin.from("vss_admin_accounts")
      .select("user_id").eq("user_id", userId).maybeSingle();
    if (lookupError || !target) return json({ error: lookupError?.message || "Admin account not found." }, 404);
    const { error } = await admin.from("vss_admin_accounts")
      .update({ is_active: isActive, updated_at: new Date().toISOString() }).eq("user_id", userId);
    if (error) return json({ error: error.message }, 400);
    return json({ success: true, message: isActive ? "Admin access activated." : "Admin access deactivated." });
  }

  if (action === "reset_password") {
    const userId = String(body.user_id || "");
    const password = String(body.password || "");
    if (!userId || password.length < 12) return json({ error: "A new password of at least 12 characters is required." }, 400);
    const { data: target, error: lookupError } = await admin.from("vss_admin_accounts")
      .select("user_id").eq("user_id", userId).maybeSingle();
    if (lookupError || !target) return json({ error: lookupError?.message || "Admin account not found." }, 404);
    const { error } = await admin.auth.admin.updateUserById(userId, { password });
    if (error) return json({ error: error.message }, 400);
    return json({ success: true, message: "Password updated." });
  }
  return json({ error: "Unsupported action." }, 400);
});
