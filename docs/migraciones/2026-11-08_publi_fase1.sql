-- Proyecto: Kirolorik
-- Archivo: 2026-11-08_publi_fase1.sql
-- Versión: v0.01
-- Fecha: 2026-11-08
-- Explicación: Publicidad, fase 1. Modelo para anunciantes, colocaciones (banner + pueblo + fechas), exclusividad por tipo de
--   negocio y pueblo, y métricas diarias (vistas, aperturas y clics).
--   A. tipos_negocio (lista cerrada; «otros» no es exclusivo).
--   B. anunciantes: id legible (codigo), razón social, CIF, provincia, dirección fiscal y tipo de negocio.
--   C. anunciante_usuarios: qué logins gestionan cada anunciante (un anunciante puede tener varios).
--   D. colocaciones: una fila por banner y pueblo (municipio_id NULL = todos los pueblos). Exclusividad por restricción.
--   E. banner_metricas_diarias + función registrar_evento_banner (la portada ya no escribe en banner_clicks).
--   F. Vista banners_publicos: lo que la portada debe mostrar hoy en cada pueblo.
--   G. Rellena colocaciones y métricas a partir de los banners y clics actuales.
-- La portada sigue funcionando sin cambios con esta migración (banners y banner_clicks no se tocan). El código nuevo se
-- publica después.
-- PROBAR PRIMERO dentro de una transacción que se deshace (ver el ensayo). Reversión al final del archivo.

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA extensions;

-- ============ Utilidades ============
CREATE OR REPLACE FUNCTION public.es_admin() RETURNS boolean
  LANGUAGE sql STABLE SET search_path = public AS $$ SELECT auth.email() = 'kirolorik.app@gmail.com' $$;

-- ============ A. Tipos de negocio ============
CREATE TABLE public.tipos_negocio (
  id        text PRIMARY KEY,
  nombre    text NOT NULL,
  exclusivo boolean NOT NULL DEFAULT true,
  activo    boolean NOT NULL DEFAULT true,
  orden     integer NOT NULL DEFAULT 0
);
INSERT INTO public.tipos_negocio (id, nombre, exclusivo, orden) VALUES
  ('hosteleria',   'Bares y restaurantes',               true, 10),
  ('alimentacion', 'Alimentación y productores locales', true, 20),
  ('comercio',     'Tiendas y comercio local',           true, 30),
  ('salud',        'Salud, fisioterapia y bienestar',    true, 40),
  ('deporte',      'Gimnasios y material deportivo',     true, 50),
  ('automocion',   'Automoción y talleres',              true, 60),
  ('servicios',    'Servicios profesionales y seguros',  true, 70),
  ('inmobiliaria', 'Inmobiliarias',                      true, 80),
  ('educacion',    'Academias y formación',              true, 90),
  ('ocio',         'Ocio y turismo',                     true, 100),
  ('tecnologia',   'Tecnología y aplicaciones',          true, 110),
  ('otros',        'Otros (sin exclusividad)',           false, 999);
ALTER TABLE public.tipos_negocio ENABLE ROW LEVEL SECURITY;
CREATE POLICY tipos_negocio_lectura ON public.tipos_negocio FOR SELECT TO anon, authenticated USING (activo);
CREATE POLICY tipos_negocio_admin   ON public.tipos_negocio FOR ALL TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());
REVOKE ALL ON public.tipos_negocio FROM anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.tipos_negocio FROM authenticated;
GRANT SELECT ON public.tipos_negocio TO anon;

-- ============ B. Anunciantes ============
CREATE SEQUENCE IF NOT EXISTS public.anunciantes_codigo_seq;
ALTER TABLE public.anunciantes
  ADD COLUMN IF NOT EXISTS codigo           text,
  ADD COLUMN IF NOT EXISTS razon_social     text,
  ADD COLUMN IF NOT EXISTS cif              text,
  ADD COLUMN IF NOT EXISTS provincia        text,
  ADD COLUMN IF NOT EXISTS direccion_fiscal text,
  ADD COLUMN IF NOT EXISTS tipo_negocio     text REFERENCES public.tipos_negocio(id),
  ADD COLUMN IF NOT EXISTS updated_at       timestamptz DEFAULT now();
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM public.anunciantes WHERE codigo IS NULL ORDER BY created_at LOOP
    UPDATE public.anunciantes SET codigo = 'A-' || lpad(nextval('public.anunciantes_codigo_seq')::text, 4, '0') WHERE id = r.id;
  END LOOP;
END $$;
ALTER TABLE public.anunciantes ALTER COLUMN codigo SET DEFAULT ('A-' || lpad(nextval('public.anunciantes_codigo_seq')::text, 4, '0'));
ALTER TABLE public.anunciantes ALTER COLUMN codigo SET NOT NULL;
CREATE UNIQUE INDEX anunciantes_codigo_uq ON public.anunciantes (codigo);
CREATE UNIQUE INDEX anunciantes_cif_uq    ON public.anunciantes (upper(cif)) WHERE cif IS NOT NULL;
UPDATE public.anunciantes SET tipo_negocio = 'otros' WHERE tipo_negocio IS NULL;

-- ============ C. Logins de cada anunciante ============
CREATE TABLE public.anunciante_usuarios (
  user_id        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anunciante_id  uuid NOT NULL REFERENCES public.anunciantes(id) ON DELETE CASCADE,
  rol            text NOT NULL DEFAULT 'gestor' CHECK (rol IN ('propietario','gestor')),
  activo         boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, anunciante_id)
);
ALTER TABLE public.anunciante_usuarios ENABLE ROW LEVEL SECURITY;
CREATE POLICY anunciante_usuarios_propios ON public.anunciante_usuarios FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY anunciante_usuarios_admin   ON public.anunciante_usuarios FOR ALL TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());
REVOKE ALL ON public.anunciante_usuarios FROM anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.anunciante_usuarios FROM authenticated;

-- ¿Gestiona el usuario actual este anunciante? (SECURITY DEFINER para no enlazar políticas entre sí)
CREATE OR REPLACE FUNCTION public.anunciante_del_usuario(a uuid) RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.anunciante_usuarios au WHERE au.anunciante_id = a AND au.user_id = auth.uid() AND au.activo)
$$;
REVOKE ALL ON FUNCTION public.anunciante_del_usuario(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.anunciante_del_usuario(uuid) TO authenticated;

CREATE POLICY anunciantes_propio_select ON public.anunciantes FOR SELECT TO authenticated USING (public.anunciante_del_usuario(id));
CREATE POLICY banners_propios_select    ON public.banners     FOR SELECT TO authenticated USING (public.anunciante_del_usuario(anunciante_id));

-- ============ D. Colocaciones (banner + pueblo + fechas) ============
CREATE TABLE public.colocaciones (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  banner_id              uuid NOT NULL REFERENCES public.banners(id) ON DELETE CASCADE,
  municipio_id           uuid REFERENCES public.municipios(id),          -- NULL = todos los pueblos
  estado                 text NOT NULL DEFAULT 'borrador'
                         CHECK (estado IN ('borrador','revision','rechazada','pendiente_pago','confirmada','pausada','cancelada')),
  fecha_inicio           date NOT NULL,
  fecha_fin              date,                                             -- NULL = sin fecha de fin (renovación automática)
  origen                 text NOT NULL DEFAULT 'pago' CHECK (origen IN ('pago','cortesia','acuerdo')),
  modo_renovacion        text NOT NULL DEFAULT 'prepago' CHECK (modo_renovacion IN ('prepago','automatica')),
  tarifa_id              uuid REFERENCES public.tarifas(id),
  stripe_subscription_id text,
  orden                  integer NOT NULL DEFAULT 0,
  motivo_rechazo         text,
  notas                  text,
  tipo_negocio           text,                                             -- copia del anunciante, para la exclusividad
  exclusivo              boolean NOT NULL DEFAULT false,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
  -- Un tipo de negocio exclusivo solo puede tener una colocación en cada pueblo en las mismas fechas
  CONSTRAINT colocaciones_exclusividad EXCLUDE USING gist (
    municipio_id WITH =, tipo_negocio WITH =, daterange(fecha_inicio, fecha_fin, '[]') WITH &&
  ) WHERE (municipio_id IS NOT NULL AND exclusivo AND estado IN ('pendiente_pago','confirmada','pausada'))
);
CREATE INDEX colocaciones_banner_idx    ON public.colocaciones (banner_id);
CREATE INDEX colocaciones_municipio_idx ON public.colocaciones (municipio_id, estado);

CREATE OR REPLACE FUNCTION public.trg_colocaciones_tipo() RETURNS trigger
  LANGUAGE plpgsql SET search_path = public AS $$
DECLARE t text; ex boolean;
BEGIN
  SELECT a.tipo_negocio, tn.exclusivo INTO t, ex
    FROM public.banners b
    LEFT JOIN public.anunciantes a ON a.id = b.anunciante_id
    LEFT JOIN public.tipos_negocio tn ON tn.id = a.tipo_negocio
   WHERE b.id = NEW.banner_id;
  NEW.tipo_negocio := COALESCE(t, 'otros');
  NEW.exclusivo    := COALESCE(ex, false);
  NEW.updated_at   := now();
  RETURN NEW;
END $$;
CREATE TRIGGER colocaciones_tipo BEFORE INSERT OR UPDATE ON public.colocaciones
  FOR EACH ROW EXECUTE FUNCTION public.trg_colocaciones_tipo();

ALTER TABLE public.colocaciones ENABLE ROW LEVEL SECURITY;
CREATE POLICY colocaciones_admin  ON public.colocaciones FOR ALL TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());
CREATE POLICY colocaciones_propias ON public.colocaciones FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.banners b WHERE b.id = banner_id AND public.anunciante_del_usuario(b.anunciante_id)));
REVOKE ALL ON public.colocaciones FROM anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.colocaciones FROM authenticated;

-- ============ E. Métricas diarias ============
CREATE TABLE public.banner_metricas_diarias (
  colocacion_id uuid NOT NULL REFERENCES public.colocaciones(id) ON DELETE CASCADE,
  municipio     text NOT NULL DEFAULT '',     -- pueblo desde el que se vio (importa en las colocaciones de «todos los pueblos»)
  fecha         date NOT NULL,
  vistas        integer NOT NULL DEFAULT 0,
  aperturas     integer NOT NULL DEFAULT 0,
  clics         integer NOT NULL DEFAULT 0,
  PRIMARY KEY (colocacion_id, municipio, fecha)
);
ALTER TABLE public.banner_metricas_diarias ENABLE ROW LEVEL SECURITY;
CREATE POLICY metricas_admin   ON public.banner_metricas_diarias FOR SELECT TO authenticated USING (public.es_admin());
CREATE POLICY metricas_propias ON public.banner_metricas_diarias FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.colocaciones c JOIN public.banners b ON b.id = c.banner_id
                 WHERE c.id = colocacion_id AND public.anunciante_del_usuario(b.anunciante_id)));
REVOKE ALL ON public.banner_metricas_diarias FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.banner_metricas_diarias FROM authenticated;

-- La portada llama a esta función (no escribe en la tabla). Solo cuenta colocaciones en vigor.
CREATE OR REPLACE FUNCTION public.registrar_evento_banner(p_colocacion uuid, p_tipo text, p_municipio text DEFAULT '')
  RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hoy date := (now() AT TIME ZONE 'Europe/Madrid')::date;
BEGIN
  IF p_tipo NOT IN ('vista','apertura','clic') THEN RETURN; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.colocaciones c
                 WHERE c.id = p_colocacion AND c.estado = 'confirmada'
                   AND hoy BETWEEN c.fecha_inicio AND COALESCE(c.fecha_fin, 'infinity'::date)) THEN RETURN; END IF;
  INSERT INTO public.banner_metricas_diarias (colocacion_id, municipio, fecha, vistas, aperturas, clics)
  VALUES (p_colocacion, left(COALESCE(p_municipio, ''), 60), hoy,
          (p_tipo = 'vista')::int, (p_tipo = 'apertura')::int, (p_tipo = 'clic')::int)
  ON CONFLICT (colocacion_id, municipio, fecha) DO UPDATE SET
    vistas    = banner_metricas_diarias.vistas    + EXCLUDED.vistas,
    aperturas = banner_metricas_diarias.aperturas + EXCLUDED.aperturas,
    clics     = banner_metricas_diarias.clics     + EXCLUDED.clics;
END $$;
REVOKE ALL ON FUNCTION public.registrar_evento_banner(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_evento_banner(uuid, text, text) TO anon, authenticated;

-- ============ F. Lo que la portada muestra hoy ============
CREATE VIEW public.banners_publicos AS
  SELECT c.id AS colocacion_id, b.id AS banner_id, b.nombre, b.descripcion, b.texto, b.imagen_url, b.url_destino,
         m.nombre AS municipio, c.orden
    FROM public.colocaciones c
    JOIN public.banners b       ON b.id = c.banner_id AND COALESCE(b.activo, false)
    JOIN public.anunciantes a   ON a.id = b.anunciante_id AND COALESCE(a.activo, false)
    LEFT JOIN public.municipios m ON m.id = c.municipio_id
   WHERE c.estado = 'confirmada'
     AND (now() AT TIME ZONE 'Europe/Madrid')::date BETWEEN c.fecha_inicio AND COALESCE(c.fecha_fin, 'infinity'::date);
REVOKE ALL ON public.banners_publicos FROM anon, authenticated;
GRANT SELECT ON public.banners_publicos TO anon, authenticated;

-- ============ G. Datos actuales ============
INSERT INTO public.colocaciones (banner_id, municipio_id, estado, fecha_inicio, fecha_fin, origen, orden)
SELECT b.id,
       (SELECT m.id FROM public.municipios m WHERE lower(m.nombre) = lower(b.municipio) LIMIT 1),
       CASE WHEN b.activo THEN 'confirmada' ELSE 'pausada' END,
       COALESCE(b.fecha_inicio, b.created_at::date),
       CASE WHEN b.fecha_fin >= COALESCE(b.fecha_inicio, b.created_at::date) THEN b.fecha_fin END,
       'cortesia', COALESCE(b.orden, 0)
  FROM public.banners b;

INSERT INTO public.banner_metricas_diarias (colocacion_id, municipio, fecha, clics)
SELECT c.id, '', (k.clicked_at AT TIME ZONE 'Europe/Madrid')::date, count(*)
  FROM public.banner_clicks k JOIN public.colocaciones c ON c.banner_id = k.banner_id
 GROUP BY 1, 3
ON CONFLICT DO NOTHING;

-- ============ REVERSIÓN ============
-- DROP VIEW public.banners_publicos;
-- DROP FUNCTION public.registrar_evento_banner(uuid, text, text);
-- DROP TABLE public.banner_metricas_diarias, public.colocaciones, public.anunciante_usuarios, public.tipos_negocio;
-- DROP POLICY anunciantes_propio_select ON public.anunciantes;  DROP POLICY banners_propios_select ON public.banners;
-- DROP FUNCTION public.anunciante_del_usuario(uuid); DROP FUNCTION public.trg_colocaciones_tipo();
-- ALTER TABLE public.anunciantes DROP COLUMN codigo, DROP COLUMN razon_social, DROP COLUMN cif, DROP COLUMN provincia,
--   DROP COLUMN direccion_fiscal, DROP COLUMN tipo_negocio, DROP COLUMN updated_at;  DROP SEQUENCE public.anunciantes_codigo_seq;
