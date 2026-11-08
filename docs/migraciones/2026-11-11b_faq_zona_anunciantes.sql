-- Proyecto: Kirolorik
-- Archivo: 2026-11-11b_faq_zona_anunciantes.sql
-- Versión: v0.01
-- Fecha: 2026-11-11
-- Explicación: FAQ de anunciantes actualizada para la zona de anunciantes: tres respuestas que decían «próximamente» pasan a describir
--   lo que ya existe, y dos preguntas nuevas (acceso y solicitud de visibilidad). Ejecutar cuando la zona de anunciantes esté en producción.
-- Reversión: restaurar las respuestas desde 2026-11-09_publi_faq_facturas_disenos.sql y 2026-11-10_faq_pueblos_fechas.sql;
--   DELETE FROM public.faq WHERE categoria = 'publicidad' AND orden IN (160,170);

UPDATE public.faq SET respuesta = 'Escríbenos a kirolorik.info@gmail.com indicando el nombre de tu negocio, el tipo de negocio (por ejemplo bar, tienda, fisioterapia…) y el pueblo o pueblos donde quieres aparecer. Te damos acceso a tu zona de anunciantes, donde creas tu banner, solicitas la visibilidad (pueblo y plan mensual, trimestral o anual) y ves los resultados.'
 WHERE categoria = 'publicidad' AND orden = 10;
UPDATE public.faq SET respuesta = 'Desde tu zona de anunciantes, al solicitar visibilidad, pulsa «¿Tu pueblo no está? Solicitar uno nuevo» y lo añadimos. También puedes escribirnos a kirolorik.info@gmail.com. El pueblo aparece en el selector de la portada cuando tiene eventos.'
 WHERE categoria = 'publicidad' AND orden = 140;
UPDATE public.faq SET respuesta = 'Sí. Desde tu zona de anunciantes, en «Diseño», cuéntanos qué quieres anunciar, tus colores y tu logotipo, y lo diseñamos nosotros. Te indicamos el precio al recibir la solicitud. (Próximamente podrás elegir también entre diseñadores colaboradores.)'
 WHERE categoria = 'publicidad' AND orden = 100;

INSERT INTO public.faq (categoria, pregunta, respuesta, orden, activo) VALUES
('publicidad', '¿Cómo accedo a mi zona de anunciantes?',
 'Entra en kirolorik.app/pages/anunciantes.html con el email y la contraseña que te facilitamos. Puedes cambiar la contraseña desde tu perfil o con «¿Has olvidado la contraseña?». Puedes marcar «Mantener sesión iniciada» para no tener que entrar cada vez.', 160, true),
('publicidad', '¿Cómo funciona la solicitud de visibilidad?',
 'Creas tu banner en tu zona de anunciantes y pulsas «Solicitar visibilidad»: eliges el pueblo (o varios), el plan (mensual, trimestral o anual) y si prefieres prepago o renovación automática. Revisamos el banner y la solicitud; al aprobarla se fijan las fechas según el plan y te indicamos el precio y cómo pagar. Cuando el pago está confirmado, tu banner se publica. Mientras la solicitud está en revisión puedes cancelarla.', 170, true);
