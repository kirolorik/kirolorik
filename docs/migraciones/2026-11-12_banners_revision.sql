-- Proyecto: Kirolorik
-- Archivo: 2026-11-12_banners_revision.sql
-- Versión: v0.01
-- Fecha: 2026-11-12
-- Explicación: La revisión del CONTENIDO del banner pasa a ser un paso independiente de la SOLICITUD de visibilidad.
--   1. El anunciante crea banners (borrador), los envía a revisión cuando quiere y Kirolorik los aprueba o rechaza (con motivo).
--   2. Solo un banner aprobado se puede usar para solicitar visibilidad (pueblo, plan y renovación), cuando el anunciante quiera.
--   banners.estado_contenido: borrador → revision → aprobado | rechazado. Los banners que ya existen (creados por Kirolorik) quedan
--   aprobados. El anunciante no puede aprobar ni rechazar; si edita un banner aprobado tiene que volver a enviarlo a revisión.
-- Requiere 2026-11-11_zona_anunciantes.sql. Reversión al final.

ALTER TABLE public.banners
  ADD COLUMN estado_contenido text NOT NULL DEFAULT 'aprobado'
    CHECK (estado_contenido IN ('borrador','revision','aprobado','rechazado')),
  ADD COLUMN motivo_rechazo text;

-- El anunciante crea sus banners en borrador y solo puede dejarlos en borrador o enviarlos a revisión
DROP POLICY IF EXISTS banners_propios_insert ON public.banners;
CREATE POLICY banners_propios_insert ON public.banners FOR INSERT TO authenticated
  WITH CHECK (public.anunciante_del_usuario(anunciante_id) AND activo = false AND estado_contenido = 'borrador' AND motivo_rechazo IS NULL);

DROP POLICY IF EXISTS banners_propios_update ON public.banners;
CREATE POLICY banners_propios_update ON public.banners FOR UPDATE TO authenticated
  USING (public.anunciante_del_usuario(anunciante_id)
         AND NOT EXISTS (SELECT 1 FROM public.colocaciones c WHERE c.banner_id = banners.id
                         AND c.estado IN ('pendiente_pago','confirmada','pausada')
                         AND (c.fecha_fin IS NULL OR c.fecha_fin >= current_date)))
  WITH CHECK (public.anunciante_del_usuario(anunciante_id) AND activo = false AND estado_contenido IN ('borrador','revision'));

-- Solo se puede solicitar visibilidad con un banner aprobado
DROP POLICY IF EXISTS colocaciones_solicitar ON public.colocaciones;
CREATE POLICY colocaciones_solicitar ON public.colocaciones FOR INSERT TO authenticated
  WITH CHECK (
    estado = 'revision' AND fecha_inicio IS NULL AND fecha_fin IS NULL AND origen = 'pago' AND municipio_id IS NOT NULL
    AND tarifa_id IS NOT NULL AND modo_renovacion IN ('prepago','automatica') AND stripe_subscription_id IS NULL
    AND motivo_rechazo IS NULL AND notas IS NULL AND orden = 0 AND solicitada_por = auth.uid()
    AND EXISTS (SELECT 1 FROM public.banners b WHERE b.id = banner_id AND b.estado_contenido = 'aprobado'
                AND public.anunciante_del_usuario(b.anunciante_id))
    AND EXISTS (SELECT 1 FROM public.tarifas t WHERE t.id = tarifa_id AND t.activo AND t.periodo IN ('mes','trimestre','año')));

-- ============ REVERSIÓN ============
-- (restaurar las políticas de 2026-11-11_zona_anunciantes.sql sin estado_contenido)
-- ALTER TABLE public.banners DROP COLUMN estado_contenido, DROP COLUMN motivo_rechazo;
