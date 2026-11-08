-- Proyecto: Kirolorik
-- Archivo: 2026-11-09_publi_faq_facturas_disenos.sql
-- Versión: v0.01
-- Fecha: 2026-11-09
-- Explicación: Publicidad, fase 1b. Requiere haber aplicado 2026-11-08_publi_fase1.sql.
--   A. Preguntas frecuentes para anunciantes (categoría «publicidad» de la FAQ). Las respuestas que dependen de fases aún
--      no terminadas (pago online, facturas descargables, diseñadores) llevan «(próximamente)» para completarlas después.
--   B. disenadores: directorio de diseñadores colaboradores (solo admin por ahora).
--   C. disenos_banner: solicitudes de diseño de un banner (primero las atiende Kirolorik; más adelante, diseñadores).
--   D. facturas: una fila por factura (número, fecha, importe, enlace al documento); se rellena a mano y más adelante desde Stripe.
-- PROBAR PRIMERO en transacción que se deshace. Reversión al final.

-- ============ A. FAQ de anunciantes ============
INSERT INTO public.faq (categoria, pregunta, respuesta, orden, activo) VALUES
('publicidad', '¿Cómo puedo anunciar mi negocio en Kirolorik?',
 'Escríbenos a kirolorik.info@gmail.com indicando el nombre de tu negocio, el tipo de negocio (por ejemplo bar, tienda, fisioterapia…) y el pueblo o pueblos donde quieres aparecer. Te ayudamos a preparar el banner y lo programamos en las fechas que elijas. (Próximamente: zona de anunciantes para hacerlo tú mismo.)', 10, true),
('publicidad', '¿Dónde se ve mi banner?',
 'En la barra de publicidad de la portada, en los pueblos y fechas que hayas contratado. Al tocarla se abre tu ficha con la imagen, el texto y un botón con tu enlace (web, WhatsApp, email o teléfono).', 20, true),
('publicidad', '¿Qué es la exclusividad por tipo de negocio?',
 'En cada pueblo solo puede haber un anunciante de cada tipo de negocio al mismo tiempo (por ejemplo, un solo bar o restaurante). Si el hueco de tu tipo de negocio está libre en las fechas que quieres, es tuyo en exclusiva. Si está ocupado, te proponemos otras fechas u otro pueblo.', 30, true),
('publicidad', '¿Qué necesito para crear mi banner?',
 'Un título (el nombre de tu negocio o tu oferta), una descripción corta de unos 60 caracteres que se ve en la barra, un texto más largo opcional que se ve al abrirlo, una imagen (JPG, PNG, WebP o GIF de hasta 5 MB; mejor horizontal) y el enlace al que quieres llevar a la gente. Revisamos cada banner antes de publicarlo.', 40, true),
('publicidad', '¿Puedo anunciarme en varios pueblos?',
 'Sí. El mismo banner puede aparecer en varios pueblos, cada uno con sus fechas, y verás los resultados por separado para saber dónde funciona mejor.', 50, true),
('publicidad', '¿Qué resultados puedo ver?',
 'Vistas (cuántas veces se ha mostrado tu banner), aperturas (cuántas veces se ha abierto tu ficha), clics (cuántas veces se ha pulsado tu botón) y el porcentaje de clics sobre vistas, por pueblo y por día. Te facilitamos el informe y también puede descargarse en una hoja de cálculo. No contamos las visitas del equipo de Kirolorik.', 60, true),
('publicidad', '¿Cuánto cuesta y cómo se paga?',
 'Hay planes por evento, por jornada, mensual, trimestral, semestral y anual. Escríbenos y te indicamos las tarifas vigentes para tu pueblo. Hoy te enviamos los datos para pagar; (próximamente) podrás pagar online con tarjeta de forma segura.', 70, true),
('publicidad', '¿Se renueva automáticamente?',
 'Habrá dos formas: prepago por periodo (al acabar te avisamos para renovar) o renovación automática (se cobra cada periodo hasta que la canceles, sin permanencia). (Próximamente: la renovación automática estará disponible con el pago online.)', 80, true),
('publicidad', '¿Cómo recibo la factura?',
 'Emitimos factura de cada pago con tus datos fiscales (razón social, CIF y dirección fiscal), que nos facilitas al darte de alta. Por ahora te la enviamos por email. (Próximamente: podrás ver y descargar todas tus facturas desde tu zona de anunciante.)', 90, true),
('publicidad', '¿Pueden diseñarme el banner?',
 'Sí. Cuéntanos qué quieres anunciar, tus colores y tu logotipo, y lo diseñamos nosotros. (Próximamente podrás elegir también entre diseñadores colaboradores.) Consulta el precio del diseño al solicitarlo.', 100, true),
('publicidad', '¿Puedo pausar o cancelar mi banner?',
 'Sí. Escríbenos y lo pausamos o lo cancelamos; al cancelar, el hueco queda libre. Las condiciones de cancelación y reembolso se detallan en las condiciones de contratación.', 110, true);

-- ============ B. Diseñadores colaboradores ============
CREATE TABLE public.disenadores (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre         text NOT NULL,
  email          text,
  web            text,
  portfolio_url  text,
  descripcion    text,
  municipio      text,
  activo         boolean NOT NULL DEFAULT false,    -- true = aceptado y visible para ofrecerle trabajos
  notas          text,
  created_at     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.disenadores ENABLE ROW LEVEL SECURITY;
CREATE POLICY disenadores_admin ON public.disenadores FOR ALL TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());
REVOKE ALL ON public.disenadores FROM anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.disenadores FROM authenticated;

-- ============ C. Solicitudes de diseño de banner ============
CREATE TABLE public.disenos_banner (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  anunciante_id  uuid NOT NULL REFERENCES public.anunciantes(id) ON DELETE CASCADE,
  banner_id      uuid REFERENCES public.banners(id) ON DELETE SET NULL,   -- banner creado con la entrega
  estado         text NOT NULL DEFAULT 'solicitado' CHECK (estado IN ('solicitado','en_curso','entregado','aprobado','cancelado')),
  origen         text NOT NULL DEFAULT 'kirolorik' CHECK (origen IN ('kirolorik','disenador')),
  disenador_id   uuid REFERENCES public.disenadores(id) ON DELETE SET NULL,
  briefing       text NOT NULL,
  referencias    text,                -- enlaces o notas: logotipo, colores, ejemplos
  entrega_url    text,                -- imagen final entregada
  precio         numeric(10,2),
  notas          text,
  solicitado_por uuid,                -- usuario que lo pidió (zona de anunciantes, más adelante)
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CHECK (origen = 'kirolorik' OR disenador_id IS NOT NULL OR estado = 'solicitado')
);
CREATE INDEX disenos_banner_anunciante_idx ON public.disenos_banner (anunciante_id, estado);
ALTER TABLE public.disenos_banner ENABLE ROW LEVEL SECURITY;
CREATE POLICY disenos_admin ON public.disenos_banner FOR ALL TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());
-- El anunciante ve sus solicitudes y puede crear nuevas (solo pidiéndolas a Kirolorik); el resto lo gestiona el admin
CREATE POLICY disenos_propios_select ON public.disenos_banner FOR SELECT TO authenticated USING (public.anunciante_del_usuario(anunciante_id));
CREATE POLICY disenos_propios_insert ON public.disenos_banner FOR INSERT TO authenticated
  WITH CHECK (public.anunciante_del_usuario(anunciante_id) AND estado = 'solicitado' AND origen = 'kirolorik'
              AND disenador_id IS NULL AND banner_id IS NULL AND entrega_url IS NULL AND precio IS NULL AND solicitado_por = auth.uid());
REVOKE ALL ON public.disenos_banner FROM anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.disenos_banner FROM authenticated;

CREATE OR REPLACE FUNCTION public.trg_actualizado() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;
CREATE TRIGGER disenos_banner_updated BEFORE UPDATE ON public.disenos_banner FOR EACH ROW EXECUTE FUNCTION public.trg_actualizado();

-- ============ D. Facturas ============
CREATE TABLE public.facturas (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  anunciante_id    uuid NOT NULL REFERENCES public.anunciantes(id) ON DELETE CASCADE,
  numero           text,                                        -- el que asigne el programa de facturación
  fecha            date NOT NULL DEFAULT current_date,
  concepto         text,
  base_imponible   numeric(10,2),
  iva_importe      numeric(10,2),
  importe_total    numeric(10,2) NOT NULL CHECK (importe_total >= 0),
  estado           text NOT NULL DEFAULT 'emitida' CHECK (estado IN ('emitida','pagada','anulada')),
  url_documento    text CHECK (url_documento IS NULL OR url_documento ~* '^https://'),
  origen           text NOT NULL DEFAULT 'manual' CHECK (origen IN ('manual','stripe')),
  pedido_id        uuid,                                        -- para la fase de pagos (tabla pedidos)
  stripe_invoice_id text,
  notas            text,
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX facturas_numero_uq ON public.facturas (numero) WHERE numero IS NOT NULL;
CREATE INDEX facturas_anunciante_idx ON public.facturas (anunciante_id, fecha DESC);
ALTER TABLE public.facturas ENABLE ROW LEVEL SECURITY;
CREATE POLICY facturas_admin  ON public.facturas FOR ALL TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());
CREATE POLICY facturas_propias ON public.facturas FOR SELECT TO authenticated USING (public.anunciante_del_usuario(anunciante_id));
REVOKE ALL ON public.facturas FROM anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.facturas FROM authenticated;

-- ============ REVERSIÓN ============
-- DROP TABLE public.facturas, public.disenos_banner, public.disenadores;  DROP FUNCTION public.trg_actualizado();
-- DELETE FROM public.faq WHERE categoria = 'publicidad' AND orden IN (10,20,30,40,50,60,70,80,90,100,110);
