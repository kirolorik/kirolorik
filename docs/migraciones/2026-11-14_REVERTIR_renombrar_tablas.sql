-- Proyecto: Kirolorik
-- Archivo: docs/migraciones/2026-11-14_REVERTIR_renombrar_tablas.sql
-- Versión: v0.01 · 2026-11-14
-- Descripción: deshace 2026-11-14_renombrar_tablas.sql (vuelve a los nombres antiguos de tablas, disparadores, políticas y funciones).
--   Las restricciones/índices/secuencias renombrados conservan el nombre nuevo (no afecta al funcionamiento).
--   Las copias del esquema "backup" se quedan allí (ALTER TABLE backup.<t> SET SCHEMA public si se quieren devolver).
BEGIN;
DROP VIEW IF EXISTS public.perfil_club, public.mis_equipos, public.anunciante_usuarios, public.facturas,
  public.solicitudes_pueblo, public.disenos_banner, public.page_views, public.evento_views, public.perfiles;
ALTER TABLE IF EXISTS public.club_gestores RENAME TO perfil_club;
ALTER TABLE IF EXISTS public.equipos RENAME TO mis_equipos;
ALTER TABLE IF EXISTS public.anunciante_gestores RENAME TO anunciante_usuarios;
ALTER TABLE IF EXISTS public.anunciante_facturas RENAME TO facturas;
ALTER TABLE IF EXISTS public.anunciante_solicitudes RENAME TO solicitudes_pueblo;
ALTER TABLE IF EXISTS public.banner_disenos RENAME TO disenos_banner;
ALTER TABLE IF EXISTS public.analitica_visitas RENAME TO page_views;
ALTER TABLE IF EXISTS public.analitica_eventos RENAME TO evento_views;
ALTER TABLE IF EXISTS public.usuarios_perfil RENAME TO perfiles;
ALTER TRIGGER banner_disenos_updated ON public.disenos_banner RENAME TO disenos_banner_updated;
ALTER TRIGGER equipos_eventos ON public.mis_equipos RENAME TO mis_equipos_eventos;
ALTER TRIGGER equipos_nombre ON public.mis_equipos RENAME TO mis_equipos_nombre;
ALTER POLICY equipos_write ON public.mis_equipos RENAME TO mis_equipos_write;

-- 2 · Funciones con los nombres antiguos
CREATE OR REPLACE FUNCTION public.anunciante_del_usuario(a uuid) RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.anunciante_usuarios au WHERE au.anunciante_id = a AND au.user_id = auth.uid() AND au.activo)
$$;

CREATE OR REPLACE FUNCTION public.es_anunciante() RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.anunciante_usuarios au WHERE au.user_id = auth.uid() AND au.activo)
$$;

CREATE OR REPLACE FUNCTION public.es_gestor_club() RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.es_admin()
      OR EXISTS (SELECT 1 FROM public.perfil_club pc WHERE pc.user_id = auth.uid() AND pc.activo)
$$;

CREATE OR REPLACE FUNCTION public.mis_roles() RETURNS jsonb
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'admin',       public.es_admin(),
    'club',        public.es_gestor_club(),
    'anunciante',  public.es_anunciante(),
    'clubes',      COALESCE((SELECT jsonb_agg(jsonb_build_object('club_id', pc.club_id, 'rol', pc.rol))
                               FROM public.perfil_club pc WHERE pc.user_id = auth.uid() AND pc.activo), '[]'::jsonb),
    'anunciantes', COALESCE((SELECT jsonb_agg(au.anunciante_id)
                               FROM public.anunciante_usuarios au WHERE au.user_id = auth.uid() AND au.activo), '[]'::jsonb))
$$;

CREATE OR REPLACE FUNCTION public.sync_municipio_equipo() RETURNS trigger
  LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.equipo_id IS NOT NULL THEN
    SELECT municipio INTO NEW.municipio_equipo
    FROM mis_equipos
    WHERE id = NEW.equipo_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_clubes_refrescar_equipos() RETURNS trigger
  LANGUAGE plpgsql SET search_path = public AS $$
begin
  if new.nombre is distinct from old.nombre or new.nombre_corto is distinct from old.nombre_corto then
    update public.mis_equipos set nombre = nombre where club_id = new.id and nombre_auto;
  end if;
  return new;
end $$;


COMMIT;
