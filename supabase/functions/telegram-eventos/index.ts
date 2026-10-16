// Kirolorik · telegram-eventos/index.ts · v1.0 · 2026-10-17
// Webhook de Telegram: recibe un cartel, una captura o un texto, extrae los eventos con Claude
// y los guarda como borradores (eventos_borrador) para revisarlos y publicarlos en admin/eventos.html.
import Anthropic from 'npm:@anthropic-ai/sdk@0.135.0';
import { createClient } from 'npm:@supabase/supabase-js@2';
import { buildSystemPrompt, EXTRACT_SCHEMA, normalizarEvento, parsearRespuesta, soloEnlaces } from './extract.ts';

const TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN') || '';
const WEBHOOK_SECRET = Deno.env.get('TELEGRAM_WEBHOOK_SECRET') || '';
const MODELO = 'claude-opus-5-5';
const MAX_IMG = 5 * 1024 * 1024;

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

async function tg(metodo: string, cuerpo: Record<string, unknown>) {
  const r = await fetch(`https://api.telegram.org/bot${TOKEN}/${metodo}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(cuerpo),
  });
  if (!r.ok) console.error('telegram', metodo, r.status, await r.text());
  return r;
}

function responder(chatId: number, texto: string, replyTo?: number) {
  const cuerpo: Record<string, unknown> = { chat_id: chatId, text: texto.slice(0, 4000), disable_web_page_preview: true };
  if (replyTo) cuerpo.reply_parameters = { message_id: replyTo, allow_sending_without_reply: true };
  return tg('sendMessage', cuerpo);
}

const AYUDA = `Cómo funciona:
• Manda una captura o el cartel del evento (con el texto del post como pie de foto si quieres).
• O pega el texto del post.
• Los enlaces de Instagram no los puedo leer: manda la captura o copia el texto.
Cada evento que encuentre queda como borrador en Kirolorik > Admin > Borradores. Allí lo revisas y lo publicas.`;

function hoyMadrid() {
  const ahora = new Date();
  const iso = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Madrid' }).format(ahora);
  const dia = new Intl.DateTimeFormat('es-ES', { timeZone: 'Europe/Madrid', weekday: 'long' }).format(ahora);
  return { iso, dia };
}

async function listaMunicipios(): Promise<string[]> {
  const set = new Set<string>();
  const [a, b] = await Promise.all([
    sb.from('eventos').select('municipio').not('municipio', 'is', null).limit(2000),
    sb.from('mis_equipos').select('municipio').not('municipio', 'is', null).limit(2000),
  ]);
  for (const f of [...(a.data || []), ...(b.data || [])]) if (f.municipio) set.add(String(f.municipio).trim());
  return [...set].sort();
}

interface Imagen { b64: string; mime: string; bytes: Uint8Array; ext: string }

async function bajarImagen(fileId: string): Promise<Imagen | null> {
  const info = await (await tg('getFile', { file_id: fileId })).json();
  const ruta: string | undefined = info && info.result && info.result.file_path;
  if (!ruta) return null;
  const r = await fetch(`https://api.telegram.org/file/bot${TOKEN}/${ruta}`);
  if (!r.ok) return null;
  const bytes = new Uint8Array(await r.arrayBuffer());
  if (bytes.length > MAX_IMG) throw new Error('La imagen pesa más de 5 MB');
  const ext = (ruta.split('.').pop() || 'jpg').toLowerCase();
  const mime = ext === 'png' ? 'image/png' : ext === 'webp' ? 'image/webp' : ext === 'gif' ? 'image/gif' : 'image/jpeg';
  let bin = '';
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return { b64: btoa(bin), mime, bytes, ext: mime === 'image/jpeg' ? 'jpg' : ext };
}

async function extraer(texto: string, img: Imagen | null, municipios: string[]) {
  const { iso, dia } = hoyMadrid();
  const anthropic = new Anthropic(); // ANTHROPIC_API_KEY de los secretos de la función
  const contenido: Anthropic.ContentBlockParam[] = [];
  if (img) contenido.push({ type: 'image', source: { type: 'base64', media_type: img.mime as 'image/jpeg', data: img.b64 } });
  contenido.push({ type: 'text', text: texto ? `Texto que acompaña:\n"""\n${texto}\n"""` : 'No hay texto, solo la imagen.' });
  const base = { model: MODELO, max_tokens: 16000, system: buildSystemPrompt(iso, dia, municipios), messages: [{ role: 'user' as const, content: contenido }] };

  let resp;
  try {
    resp = await anthropic.messages.create({ ...base, output_config: { format: { type: 'json_schema', schema: EXTRACT_SCHEMA } } });
  } catch (e) {
    // Si el esquema estructurado fuera rechazado, se reintenta pidiendo JSON en el prompt
    if (e instanceof Anthropic.BadRequestError) resp = await anthropic.messages.create(base);
    else throw e;
  }
  if (resp.stop_reason === 'refusal') throw new Error('Claude no ha podido procesar este contenido');
  const t = resp.content.filter((b) => b.type === 'text').map((b) => (b as { text: string }).text).join('\n');
  return { eventos: parsearRespuesta(t).map((e) => normalizarEvento(e, iso, municipios)), iso };
}

function resumen(e: ReturnType<typeof normalizarEvento>) {
  const titulo = e.nombre_evento || `${e.equipo_local || '?'}${e.equipo_visitante ? ' vs ' + e.equipo_visitante : ''}`;
  const cuando = e.fecha
    ? new Intl.DateTimeFormat('es-ES', { weekday: 'short', day: 'numeric', month: 'short', timeZone: 'UTC' }).format(new Date(e.fecha + 'T00:00:00Z'))
    : 'sin fecha';
  return `• ${titulo} · ${cuando}${e.hora ? ' ' + e.hora : ''} · ${e.municipio || 'sin municipio'}${e.avisos ? '\n   ⚠️ ' + e.avisos : ''}`;
}

async function procesar(msg: any) {
  const chatId: number = msg.chat.id;
  const fromId: number = msg.from && msg.from.id;
  const texto: string = (msg.text || msg.caption || '').trim();

  const { data: autorizado } = await sb.from('telegram_usuarios').select('user_id').eq('telegram_id', fromId).maybeSingle();
  if (!autorizado) {
    await responder(chatId, `Hola. Todavía no tienes acceso a este bot.\nTu ID de Telegram es ${fromId}. Pásaselo al administrador de Kirolorik para que te dé de alta.`);
    return;
  }
  if (/^\/(start|ayuda|help)\b/i.test(texto)) { await responder(chatId, AYUDA); return; }

  const fotoId: string | undefined = msg.photo && msg.photo.length ? msg.photo[msg.photo.length - 1].file_id
    : msg.document && /^image\//.test(msg.document.mime_type || '') ? msg.document.file_id : undefined;
  if (!fotoId && (!texto || texto.length < 15)) { await responder(chatId, 'Mándame una captura del evento o pega el texto del post.\n\n' + AYUDA, msg.message_id); return; }
  if (!fotoId && soloEnlaces(texto)) {
    await responder(chatId, 'Los enlaces de Instagram no los puedo leer. Manda una captura del cartel o pega el texto del post.', msg.message_id);
    return;
  }

  await tg('sendChatAction', { chat_id: chatId, action: 'typing' });
  const img = fotoId ? await bajarImagen(fotoId) : null;
  const municipios = await listaMunicipios();
  const { eventos } = await extraer(texto, img, municipios);
  if (!eventos.length) { await responder(chatId, 'No he encontrado ningún evento deportivo en ese mensaje.', msg.message_id); return; }

  let imagenUrl: string | null = null;
  if (img) {
    const nombre = `telegram_${Date.now()}_${msg.message_id}.${img.ext}`;
    const sub = await sb.storage.from('eventos').upload(nombre, img.bytes, { contentType: img.mime });
    if (!sub.error) imagenUrl = sb.storage.from('eventos').getPublicUrl(nombre).data.publicUrl;
    else console.error('storage', sub.error.message);
  }

  let guardados = 0, repetidos = 0;
  const lineas: string[] = [];
  for (const e of eventos) {
    const { error } = await sb.from('eventos_borrador').insert({
      ...e, user_id: autorizado.user_id, telegram_chat_id: chatId, telegram_message_id: msg.message_id,
      fuente_texto: texto || null, imagen_url: imagenUrl,
    });
    if (error && error.code === '23505') repetidos++;
    else if (error) throw new Error(error.message);
    else { guardados++; lineas.push(resumen(e)); }
  }
  const cab = guardados === 1 ? '✅ 1 borrador:' : `✅ ${guardados} borradores:`;
  await responder(chatId, `${guardados ? cab + '\n' + lineas.join('\n') : 'Ya tenía guardado este mensaje.'}${repetidos && guardados ? `\n(${repetidos} ya estaban guardados)` : ''}\n\nRevísalos en Admin > Borradores.`, msg.message_id);
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('ok');
  if (!WEBHOOK_SECRET || req.headers.get('x-telegram-bot-api-secret-token') !== WEBHOOK_SECRET) return new Response('forbidden', { status: 403 });
  let update: any;
  try { update = await req.json(); } catch { return new Response('bad request', { status: 400 }); }
  const msg = update && update.message;
  if (!msg || !msg.chat || msg.from?.is_bot) return new Response('ok');
  // Se responde a Telegram enseguida y el trabajo (descargar, leer con Claude, guardar) sigue en segundo plano
  // @ts-ignore EdgeRuntime existe en el runtime de Supabase
  EdgeRuntime.waitUntil(procesar(msg).catch(async (err) => {
    console.error('procesar', err);
    await responder(msg.chat.id, `❌ No he podido procesarlo: ${String(err && err.message ? err.message : err).slice(0, 200)}`, msg.message_id);
  }));
  return new Response('ok');
});
