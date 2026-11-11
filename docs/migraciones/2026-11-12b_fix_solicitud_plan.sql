-- Proyecto: Kirolorik
-- Archivo: 2026-11-12b_fix_solicitud_plan.sql
-- Versión: v0.01
-- Fecha: 2026-11-12
-- Explicación: Corrige «new row violates row-level security policy for table colocaciones» al solicitar visibilidad.
--   La política colocaciones_solicitar comprobaba el plan leyendo la tabla tarifas, pero el anunciante no puede leerla (las tarifas
--   están ocultas: visible = false), así que la comprobación fallaba siempre. Ahora la comprobación la hace una función
--   SECURITY DEFINER que solo dice si el plan se puede solicitar (mensual, trimestral o anual), sin revelar precios.
-- Requiere 2026-11-12_banners_revision.sql. Reversión al final.

CREATE OR REPLACE FUNCTION public.plan_solicitable(p_tarifa uuid) RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.tarifas t WHERE t.id = p_tarifa AND t.activo AND t.periodo IN ('mes','trimestre','año'))
$$;
REVOKE ALL ON FUNCTION public.plan_solicitable(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.plan_solicitable(uuid) TO authenticated;

DROP POLICY IF EXISTS colocaciones_solicitar ON public.colocaciones;
CREATE POLICY colocaciones_solicitar ON public.colocaciones FOR INSERT TO authenticated
  WITH CHECK (
    estado = 'revision' AND fecha_inicio IS NULL AND fecha_fin IS NULL AND origen = 'pago' AND municipio_id IS NOT NULL
    AND tarifa_id IS NOT NULL AND modo_renovacion IN ('prepago','automatica') AND stripe_subscription_id IS NULL
    AND motivo_rechazo IS NULL AND notas IS NULL AND orden = 0 AND solicitada_por = auth.uid()
    AND EXISTS (SELECT 1 FROM public.banners b WHERE b.id = banner_id AND b.estado_contenido = 'aprobado'
                AND public.anunciante_del_usuario(b.anunciante_id))
    AND public.plan_solicitable(tarifa_id));

-- ============ REVERSIÓN ============
-- (volver a la política de 2026-11-12_banners_revision.sql) DROP FUNCTION public.plan_solicitable(uuid);
