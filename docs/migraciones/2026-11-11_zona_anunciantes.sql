-- Proyecto: Kirolorik
-- Archivo: 2026-11-11_zona_anunciantes.sql
-- Versión: v0.01
-- Fecha: 2026-11-11
-- Explicación: Zona de anunciantes (pages/anunciantes.html). Requiere las migraciones 2026-11-08 y 2026-11-09.
--   A. colocaciones: una SOLICITUD de visibilidad no tiene fechas (se calculan al aprobarla): fecha_inicio pasa a ser opcional
--      mientras el estado sea «revision» o similar; para pendiente_pago, confirmada y pausada sigue siendo obligatoria.
--   B. banners: ya no se pueden leer directamente desde la API pública (la portada usa la vista banners_publicos). El anunciante
--      crea y edita sus banners (siempre ocultos hasta que Kirolorik los apruebe) mientras no estén publicados.
--   C. colocaciones: el anunciante solicita visibilidad (pueblo + plan + renovación) y cancela sus solicitudes pendientes.
--   D. Funciones: planes_solicitables() (planes sin precio), huecos_ocupados() (qué pueblos tienen ocupado su tipo de negocio, sin
--      decir por quién) y mi_anunciante_actualizar() (datos de perfil que el anunciante puede cambiar).
--   E. solicitudes_pueblo: el anunciante pide que se añada un pueblo.
--   F. storage: el anunciante sube las imágenes de sus banners a la carpeta de su anunciante en el bucket banners.
-- PROBAR PRIMERO en transacción que se deshace. Reversión al final.

-- ============ A. Solicitudes sin fechas ============
ALTER TABLE public.colocaciones ALTER COLUMN fecha_inicio DROP NOT NULL;
ALTER TABLE public.colocaciones
  ADD COLUMN IF NOT EXISTS solicitada_por uuid,
  ADD COLUMN IF NOT EXISTS solicitada_at  timestamptz;
ALTER TABLE public.colocaciones
  ADD CONSTRAINT colocaciones_fechas_segun_estado
  CHECK (estado NOT IN ('pendiente_pago','confirmada','pausada') OR fecha_inicio IS NOT NULL);
-- Una sola solicitud pendiente por banner y pueblo
CREATE UNIQUE INDEX colocaciones_solicitud_uq ON public.colocaciones (banner_id, municipio_id) WHERE estado = 'revision';

-- El tipo de negocio y la exclusividad se copian siempre del anunciante, aunque quien inserte no pueda leer esas tablas
ALTER FUNCTION public.trg_colocaciones_tipo() SECURITY DEFINER SET search_path = public;

-- ============ B. Banners del anunciante ============
DROP POLICY IF EXISTS banners_publicos ON public.banners;   -- la portada lee la vista banners_publicos
CREATE POLICY banners_propios_insert ON public.banners FOR INSERT TO authenticated
  WITH CHECK (public.anunciante_del_usuario(anunciante_id) AND activo = false);
CREATE POLICY banners_propios_update ON public.banners FOR UPDATE TO authenticated
  USING (public.anunciante_del_usuario(anunciante_id)
         AND NOT EXISTS (SELECT 1 FROM public.colocaciones c WHERE c.banner_id = banners.id
                         AND c.estado IN ('pendiente_pago','confirmada','pausada')
                         AND (c.fecha_fin IS NULL OR c.fecha_fin >= current_date)))
  WITH CHECK (public.anunciante_del_usuario(anunciante_id) AND activo = false);
CREATE POLICY banners_propios_delete ON public.banners FOR DELETE TO authenticated
  USING (public.anunciante_del_usuario(anunciante_id)
         AND NOT EXISTS (SELECT 1 FROM public.colocaciones c WHERE c.banner_id = banners.id AND c.estado <> 'revision'));

-- ============ C. Solicitar visibilidad ============
CREATE POLICY colocaciones_solicitar ON public.colocaciones FOR INSERT TO authenticated
  WITH CHECK (
    estado = 'revision' AND fecha_inicio IS NULL AND fecha_fin IS NULL AND origen = 'pago' AND municipio_id IS NOT NULL
    AND tarifa_id IS NOT NULL AND modo_renovacion IN ('prepago','automatica') AND stripe_subscription_id IS NULL
    AND motivo_rechazo IS NULL AND notas IS NULL AND orden = 0 AND solicitada_por = auth.uid()
    AND EXISTS (SELECT 1 FROM public.banners b WHERE b.id = banner_id AND public.anunciante_del_usuario(b.anunciante_id))
    AND EXISTS (SELECT 1 FROM public.tarifas t WHERE t.id = tarifa_id AND t.activo AND t.periodo IN ('mes','trimestre','año')));
CREATE POLICY colocaciones_cancelar_solicitud ON public.colocaciones FOR DELETE TO authenticated
  USING (estado = 'revision'
         AND EXISTS (SELECT 1 FROM public.banners b WHERE b.id = banner_id AND public.anunciante_del_usuario(b.anunciante_id)));

-- ============ D. Funciones para la zona de anunciantes ============
-- (Supabase da EXECUTE a anon por defecto a las funciones nuevas: se quita explícitamente)
-- Planes que se pueden solicitar (sin precio: las tarifas están pendientes)
CREATE OR REPLACE FUNCTION public.planes_solicitables() RETURNS TABLE (id uuid, plan text, periodo text)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT t.id, t.plan, t.periodo FROM public.tarifas t
   WHERE t.activo AND t.periodo IN ('mes','trimestre','año')
   ORDER BY t.precio
$$;
REVOKE ALL ON FUNCTION public.planes_solicitables() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.planes_solicitables() TO authenticated;

-- Pueblos donde el tipo de negocio del anunciante ya está ocupado (sin revelar quién ni qué banner)
CREATE OR REPLACE FUNCTION public.huecos_ocupados(p_anunciante uuid)
  RETURNS TABLE (municipio_id uuid, ocupado_hasta date, indefinido boolean)
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.anunciante_del_usuario(p_anunciante) THEN RETURN; END IF;
  RETURN QUERY
    SELECT c.municipio_id, max(c.fecha_fin), bool_or(c.fecha_fin IS NULL)
      FROM public.colocaciones c
      JOIN public.anunciantes a ON a.id = p_anunciante
     WHERE c.exclusivo AND c.tipo_negocio = a.tipo_negocio AND c.municipio_id IS NOT NULL
       AND c.estado IN ('pendiente_pago','confirmada','pausada')
       AND (c.fecha_fin IS NULL OR c.fecha_fin >= current_date)
     GROUP BY c.municipio_id;
END $$;
REVOKE ALL ON FUNCTION public.huecos_ocupados(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.huecos_ocupados(uuid) TO authenticated;

-- Datos de perfil que el anunciante puede cambiar (no el tipo de negocio, el estado ni las notas)
CREATE OR REPLACE FUNCTION public.mi_anunciante_actualizar(
  p_anunciante uuid, p_razon_social text, p_cif text, p_direccion_fiscal text, p_provincia text,
  p_municipio text, p_contacto_nombre text, p_email text, p_telefono text) RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.anunciante_del_usuario(p_anunciante) THEN RAISE EXCEPTION 'No autorizado'; END IF;
  UPDATE public.anunciantes SET
    razon_social = left(nullif(trim(p_razon_social), ''), 200), cif = upper(left(nullif(trim(p_cif), ''), 20)),
    direccion_fiscal = left(nullif(trim(p_direccion_fiscal), ''), 300), provincia = left(nullif(trim(p_provincia), ''), 100),
    municipio = left(nullif(trim(p_municipio), ''), 100), contacto_nombre = left(nullif(trim(p_contacto_nombre), ''), 150),
    email = left(nullif(trim(p_email), ''), 254), telefono = left(nullif(trim(p_telefono), ''), 40), updated_at = now()
  WHERE id = p_anunciante;
END $$;
REVOKE ALL ON FUNCTION public.mi_anunciante_actualizar(uuid,text,text,text,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mi_anunciante_actualizar(uuid,text,text,text,text,text,text,text,text) TO authenticated;

-- ============ E. Solicitudes de pueblo nuevo ============
CREATE TABLE public.solicitudes_pueblo (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  anunciante_id  uuid NOT NULL REFERENCES public.anunciantes(id) ON DELETE CASCADE,
  nombre         text NOT NULL CHECK (char_length(nombre) BETWEEN 2 AND 100),
  provincia      text CHECK (provincia IS NULL OR char_length(provincia) <= 100),
  estado         text NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente','anadido','rechazado')),
  solicitada_por uuid,
  created_at     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.solicitudes_pueblo ENABLE ROW LEVEL SECURITY;
CREATE POLICY solicitudes_pueblo_admin ON public.solicitudes_pueblo FOR ALL TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());
CREATE POLICY solicitudes_pueblo_propias ON public.solicitudes_pueblo FOR SELECT TO authenticated USING (public.anunciante_del_usuario(anunciante_id));
CREATE POLICY solicitudes_pueblo_crear ON public.solicitudes_pueblo FOR INSERT TO authenticated
  WITH CHECK (public.anunciante_del_usuario(anunciante_id) AND estado = 'pendiente' AND solicitada_por = auth.uid());
REVOKE ALL ON public.solicitudes_pueblo FROM anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.solicitudes_pueblo FROM authenticated;

-- ============ F. Imágenes de los banners del anunciante ============
-- Ruta: banners/<id del anunciante>/<archivo>
CREATE POLICY subida_banners_anunciante ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'banners'
              AND (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              AND public.anunciante_del_usuario(((storage.foldername(name))[1])::uuid));

-- ============ REVERSIÓN ============
-- DROP POLICY subida_banners_anunciante ON storage.objects;
-- DROP TABLE public.solicitudes_pueblo;
-- DROP FUNCTION public.planes_solicitables(); DROP FUNCTION public.huecos_ocupados(uuid);
-- DROP FUNCTION public.mi_anunciante_actualizar(uuid,text,text,text,text,text,text,text,text);
-- DROP POLICY colocaciones_solicitar ON public.colocaciones; DROP POLICY colocaciones_cancelar_solicitud ON public.colocaciones;
-- DROP POLICY banners_propios_insert ON public.banners; DROP POLICY banners_propios_update ON public.banners; DROP POLICY banners_propios_delete ON public.banners;
-- CREATE POLICY banners_publicos ON public.banners FOR SELECT TO public USING (activo = true);
-- DROP INDEX public.colocaciones_solicitud_uq; ALTER TABLE public.colocaciones DROP CONSTRAINT colocaciones_fechas_segun_estado;
-- (fecha_inicio NOT NULL solo se puede restaurar si no hay solicitudes sin fechas)
