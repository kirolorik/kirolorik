# telegram-eventos

Bot de Telegram que convierte carteles, capturas o textos de Instagram en **borradores** de eventos
(`eventos_borrador`). Se revisan y publican en `admin/eventos.html` > pestaña **Borradores**.

Instagram no permite leer un post desde un enlace: hay que mandar una **captura** (con el texto como pie de foto, si se quiere)
o **pegar el texto**. Un cartel con varios partidos genera un borrador por partido.

## Puesta en marcha

1. En Telegram, habla con **@BotFather** > `/newbot` y guarda el token.
2. Supabase > Edge Functions > **Secrets**:
   - `TELEGRAM_BOT_TOKEN`: el token del paso 1.
   - `TELEGRAM_WEBHOOK_SECRET`: una cadena aleatoria (letras, números, `_` o `-`).
   - `ANTHROPIC_API_KEY`: clave de la API de Anthropic.
3. Conectar el bot con la función (abrir en el navegador, sustituyendo los dos valores):
   `https://api.telegram.org/bot<TOKEN>/setWebhook?url=https://glscnwctcvrosmbrljns.supabase.co/functions/v1/telegram-eventos&secret_token=<SECRET>`
4. Escribir `/start` al bot: si el usuario no está dado de alta, responde con su ID de Telegram.
5. Dar de alta al usuario: `insert into telegram_usuarios (telegram_id, user_id, nombre) values (<ID>, '<uuid de auth.users>', '<nombre>');`

## Archivos

- `index.ts`: webhook (comprueba el secreto y el usuario, descarga la imagen, llama a Claude, guarda los borradores).
- `extract.ts`: prompt, esquema y normalización de lo que devuelve Claude (lógica pura, sin red).
