-- Proyecto: Kirolorik
-- Archivo: docs/migraciones/2026-11-15_datos_personales_baja.sql
-- Versión: v0.01 · 2026-11-15
-- Descripción: datos personales ampliados y baja de cuenta unificada para las zonas de clubes y anunciantes.
--   · usuarios_perfil: nombre, telefono y avisos_email (recibir correos de la plataforma, por defecto sí).
--   · anunciantes.baja_solicitada_at: marca los negocios que se quedan sin gestor tras una baja (el admin lo ve en Publicidad).
--   · solicitar_baja_cuenta(): desactiva el perfil, quita el acceso del usuario a clubes y negocios (se puede reactivar desde el
--     admin durante 30 días), pausa los banners confirmados de los negocios que se quedan sin gestor activo y los marca.
--     No borra facturas ni datos (obligación legal de conservarlas). La cuenta de administración no se puede dar de baja aquí.
-- Reversión: bloque comentado al final.

BEGIN;

ALTER TABLE public.usuarios_perfil
  ADD COLUMN IF NOT EXISTS nombre text,
  ADD COLUMN IF NOT EXISTS telefono text,
  ADD COLUMN IF NOT EXISTS avisos_email boolean NOT NULL DEFAULT true;

-- el alias anterior pasa a ser el nombre (la ficha ya no usa alias)
UPDATE public.usuarios_perfil SET nombre = alias WHERE nombre IS NULL AND alias IS NOT NULL;

ALTER TABLE public.anunciantes
  ADD COLUMN IF NOT EXISTS baja_solicitada_at timestamptz;

CREATE OR REPLACE FUNCTION public.solicitar_baja_cuenta() RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_ids uuid[];
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'No autenticado'; END IF;
  IF public.es_admin() THEN RAISE EXCEPTION 'La cuenta de administración no se puede dar de baja desde aquí'; END IF;

  INSERT INTO public.usuarios_perfil (id, activo, baja_solicitada_at) VALUES (v_uid, false, now())
    ON CONFLICT (id) DO UPDATE SET activo = false, baja_solicitada_at = now();

  -- negocios que se quedan sin ningún gestor activo
  SELECT COALESCE(array_agg(g.anunciante_id), '{}') INTO v_ids
    FROM public.anunciante_gestores g
   WHERE g.user_id = v_uid AND g.activo
     AND NOT EXISTS (SELECT 1 FROM public.anunciante_gestores o
                      WHERE o.anunciante_id = g.anunciante_id AND o.user_id <> v_uid AND o.activo);

  UPDATE public.anunciante_gestores SET activo = false WHERE user_id = v_uid AND activo;
  UPDATE public.club_gestores       SET activo = false WHERE user_id = v_uid AND activo;

  IF cardinality(v_ids) > 0 THEN
    UPDATE public.colocaciones SET estado = 'pausada'
     WHERE estado = 'confirmada'
       AND banner_id IN (SELECT b.id FROM public.banners b WHERE b.anunciante_id = ANY (v_ids));
    UPDATE public.anunciantes SET baja_solicitada_at = now() WHERE id = ANY (v_ids);
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.solicitar_baja_cuenta() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.solicitar_baja_cuenta() TO authenticated;

COMMIT;

-- ============================================================================
-- REVERSIÓN
-- BEGIN;
-- DROP FUNCTION IF EXISTS public.solicitar_baja_cuenta();
-- ALTER TABLE public.anunciantes DROP COLUMN IF EXISTS baja_solicitada_at;
-- ALTER TABLE public.usuarios_perfil DROP COLUMN IF EXISTS nombre, DROP COLUMN IF EXISTS telefono, DROP COLUMN IF EXISTS avisos_email;
-- COMMIT;
