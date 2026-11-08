// Kirolorik · admin-users edge function · v1.1 · 2026-11-11
// Gestiona acciones administrativas sobre usuarios: reset password, cambio email, listado, desactivar y, desde la v1.1, accesos de
// anunciantes (crear usuario, vincular a un anunciante, listar accesos y quitar acceso).
// Solo accesible para kirolorik.app@gmail.com — verificado contra el JWT del caller.
// Cómo desplegarla: Supabase → Edge Functions → admin-users → Edit → pegar este archivo → Deploy (verify_jwt activado).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const ADMIN_EMAIL = "kirolorik.app@gmail.com";
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

// Contraseña legible de 12 caracteres sin caracteres ambiguos (0/O, 1/l/I)
function generarPassword(): string {
  const abc = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  return Array.from(bytes, (b) => abc[b % abc.length]).join("");
}

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
  const json = (obj: unknown, status = 200) =>
    new Response(JSON.stringify(obj), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "No autorizado" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Cliente con la key del caller para verificar quién es
    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: userErr } = await userClient.auth.getUser();
    if (userErr || !user || user.email !== ADMIN_EMAIL) return json({ error: "Acceso denegado" }, 403);

    // Cliente admin con service_role — solo server-side, nunca expuesto
    const adminClient = createClient(supabaseUrl, serviceKey);

    const body = await req.json();
    const { action, target_user_id, new_email, new_password, email, password, anunciante_id } = body;

    if (action === "list_users") {
      const { data, error } = await adminClient.auth.admin.listUsers();
      if (error) throw error;
      const users = data.users.map((u) => ({
        id: u.id, email: u.email, created_at: u.created_at,
        last_sign_in_at: u.last_sign_in_at, banned_until: u.banned_until,
      }));
      return json({ users });
    }

    if (action === "reset_password") {
      if (!target_user_id || !new_password) throw new Error("Faltan parámetros");
      if (new_password.length < 8) throw new Error("La contraseña debe tener al menos 8 caracteres");
      const { error } = await adminClient.auth.admin.updateUserById(target_user_id, { password: new_password });
      if (error) throw error;
      return json({ ok: true });
    }

    if (action === "change_email") {
      if (!target_user_id || !new_email) throw new Error("Faltan parámetros");
      const { error } = await adminClient.auth.admin.updateUserById(target_user_id, { email: new_email, email_confirm: true });
      if (error) throw error;
      return json({ ok: true });
    }

    if (action === "ban_user") {
      if (!target_user_id) throw new Error("Falta target_user_id");
      const { error } = await adminClient.auth.admin.updateUserById(target_user_id, { ban_duration: "876000h" });
      if (error) throw error;
      return json({ ok: true });
    }

    if (action === "unban_user") {
      if (!target_user_id) throw new Error("Falta target_user_id");
      const { error } = await adminClient.auth.admin.updateUserById(target_user_id, { ban_duration: "none" });
      if (error) throw error;
      return json({ ok: true });
    }

    // ── Accesos de anunciantes ──
    if (action === "create_user") {
      if (!email || !EMAIL_RE.test(String(email))) throw new Error("Email no válido");
      if (password && String(password).length < 8) throw new Error("La contraseña debe tener al menos 8 caracteres");
      const pwd = password ? String(password) : generarPassword();
      const { data, error } = await adminClient.auth.admin.createUser({ email: String(email).trim().toLowerCase(), password: pwd, email_confirm: true });
      if (error) throw error;
      if (anunciante_id) {
        const { error: e2 } = await adminClient.from("anunciante_usuarios")
          .insert({ user_id: data.user.id, anunciante_id, rol: "propietario" });
        if (e2) throw e2;
      }
      // La contraseña solo se devuelve si la ha generado la función (se muestra una vez al admin)
      return json({ ok: true, user_id: data.user.id, email: data.user.email, password: password ? null : pwd });
    }

    if (action === "link_user") {
      if (!email || !anunciante_id) throw new Error("Faltan parámetros");
      const { data, error } = await adminClient.auth.admin.listUsers({ perPage: 1000 });
      if (error) throw error;
      const u = data.users.find((x) => (x.email || "").toLowerCase() === String(email).trim().toLowerCase());
      if (!u) throw new Error("No existe ningún usuario con ese email");
      const { error: e2 } = await adminClient.from("anunciante_usuarios")
        .upsert({ user_id: u.id, anunciante_id, rol: "propietario", activo: true }, { onConflict: "user_id,anunciante_id" });
      if (e2) throw e2;
      return json({ ok: true, user_id: u.id });
    }

    if (action === "unlink_user") {
      if (!target_user_id || !anunciante_id) throw new Error("Faltan parámetros");
      const { error } = await adminClient.from("anunciante_usuarios").delete()
        .eq("user_id", target_user_id).eq("anunciante_id", anunciante_id);
      if (error) throw error;
      return json({ ok: true });
    }

    if (action === "accesos") {
      let q = adminClient.from("anunciante_usuarios").select("user_id, anunciante_id, rol, activo, created_at");
      if (anunciante_id) q = q.eq("anunciante_id", anunciante_id);
      const { data: filas, error } = await q;
      if (error) throw error;
      const { data: us, error: e2 } = await adminClient.auth.admin.listUsers({ perPage: 1000 });
      if (e2) throw e2;
      const porId = new Map(us.users.map((u) => [u.id, u]));
      const accesos = (filas || []).map((f) => ({
        ...f, email: porId.get(f.user_id)?.email || null,
        ultimo_acceso: porId.get(f.user_id)?.last_sign_in_at || null,
      }));
      return json({ accesos });
    }

    return json({ error: "Acción no reconocida" }, 400);
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message || String(e) }), {
      status: 400, headers: { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" },
    });
  }
});
