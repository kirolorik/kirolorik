-- Proyecto: Kirolorik
-- Archivo: docs/migraciones/2026-11-14_renombrar_tablas.sql
-- Versión: v0.01 · 2026-11-14
-- Descripción: normaliza los nombres de las tablas (prefijo por dominio, plural; uniones usuario↔entidad = *_gestores).
--   perfil_club           → club_gestores
--   mis_equipos           → equipos
--   anunciante_usuarios   → anunciante_gestores
--   facturas              → anunciante_facturas
--   solicitudes_pueblo    → anunciante_solicitudes
--   disenos_banner        → banner_disenos
--   page_views            → analitica_visitas
--   evento_views          → analitica_eventos
--   perfiles              → usuarios_perfil
--   bak_*                 → esquema "backup" (no expuesto por la API)
-- Qué hace: renombra (RLS, políticas, claves foráneas y disparadores se conservan), renombra índices/restricciones/secuencias,
--   recrea las 6 funciones que citaban los nombres antiguos y deja VISTAS DE COMPATIBILIDAD con los nombres viejos
--   (security_invoker → siguen aplicando RLS) para que el sitio ya publicado funcione hasta que se fusione el código nuevo.
--   Las vistas se quitan después con 2026-11-14b_quitar_vistas_compat.sql.
-- Reversión: 2026-11-14_REVERTIR_renombrar_tablas.sql.

BEGIN;

-- 0 · Esquema de copias de seguridad (fuera de la API)
CREATE SCHEMA IF NOT EXISTS backup;
REVOKE ALL ON SCHEMA backup FROM PUBLIC, anon, authenticated;
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'bak\_%' LOOP
    EXECUTE format('ALTER TABLE public.%I SET SCHEMA backup', r.tablename);
    EXECUTE format('REVOKE ALL ON backup.%I FROM PUBLIC, anon, authenticated', r.tablename);
  END LOOP;
END $$;

-- 1 · Renombrado de tablas + restricciones, índices y secuencias con el mismo prefijo
CREATE TEMP TABLE _ren(viejo text, nuevo text) ON COMMIT DROP;
INSERT INTO _ren VALUES
  ('perfil_club',         'club_gestores'),
  ('mis_equipos',         'equipos'),
  ('anunciante_usuarios', 'anunciante_gestores'),
  ('facturas',            'anunciante_facturas'),
  ('solicitudes_pueblo',  'anunciante_solicitudes'),
  ('disenos_banner',      'banner_disenos'),
  ('page_views',          'analitica_visitas'),
  ('evento_views',        'analitica_eventos'),
  ('perfiles',            'usuarios_perfil');

DO $$
DECLARE r record; x record; nn text;
BEGIN
  FOR r IN SELECT * FROM _ren LOOP
    IF to_regclass('public.' || r.viejo) IS NULL THEN CONTINUE; END IF;
    EXECUTE format('ALTER TABLE public.%I RENAME TO %I', r.viejo, r.nuevo);
    -- restricciones (las de PK/UNIQUE arrastran su índice)
    FOR x IN SELECT conname FROM pg_constraint
             WHERE conrelid = ('public.' || r.nuevo)::regclass AND conname LIKE r.viejo || '%' LOOP
      nn := r.nuevo || substr(x.conname, length(r.viejo) + 1);
      EXECUTE format('ALTER TABLE public.%I RENAME CONSTRAINT %I TO %I', r.nuevo, x.conname, nn);
    END LOOP;
    -- índices restantes (con el prefijo viejo o idx_<viejo>…)
    FOR x IN SELECT indexname FROM pg_indexes
             WHERE schemaname = 'public' AND tablename = r.nuevo
               AND (indexname LIKE r.viejo || '%' OR indexname LIKE 'idx\_' || r.viejo || '%') LOOP
      nn := replace(x.indexname, r.viejo, r.nuevo);
      IF to_regclass('public.' || nn) IS NULL THEN
        EXECUTE format('ALTER INDEX public.%I RENAME TO %I', x.indexname, nn);
      END IF;
    END LOOP;
    -- secuencias <viejo>_<col>_seq
    FOR x IN SELECT c.relname FROM pg_class c
             WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'S' AND c.relname LIKE r.viejo || '\_%' LOOP
      nn := r.nuevo || substr(x.relname, length(r.viejo) + 1);
      IF to_regclass('public.' || nn) IS NULL THEN
        EXECUTE format('ALTER SEQUENCE public.%I RENAME TO %I', x.relname, nn);
      END IF;
    END LOOP;
  END LOOP;
END $$;

-- disparadores y políticas con el nombre viejo
DO $$
BEGIN
  IF to_regclass('public.banner_disenos') IS NOT NULL AND EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'disenos_banner_updated' AND tgrelid = 'public.banner_disenos'::regclass) THEN
    ALTER TRIGGER disenos_banner_updated ON public.banner_disenos RENAME TO banner_disenos_updated;
  END IF;
  IF to_regclass('public.equipos') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'mis_equipos_eventos' AND tgrelid = 'public.equipos'::regclass) THEN
      ALTER TRIGGER mis_equipos_eventos ON public.equipos RENAME TO equipos_eventos;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'mis_equipos_nombre' AND tgrelid = 'public.equipos'::regclass) THEN
      ALTER TRIGGER mis_equipos_nombre ON public.equipos RENAME TO equipos_nombre;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'equipos' AND policyname = 'mis_equipos_write') THEN
      ALTER POLICY mis_equipos_write ON public.equipos RENAME TO equipos_write;
    END IF;
  END IF;
END $$;

-- 2 · Funciones que citaban los nombres antiguos (mismos permisos: CREATE OR REPLACE los conserva)
CREATE OR REPLACE FUNCTION public.anunciante_del_usuario(a uuid) RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.anunciante_gestores au WHERE au.anunciante_id = a AND au.user_id = auth.uid() AND au.activo)
$$;

CREATE OR REPLACE FUNCTION public.es_anunciante() RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.anunciante_gestores au WHERE au.user_id = auth.uid() AND au.activo)
$$;

CREATE OR REPLACE FUNCTION public.es_gestor_club() RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.es_admin()
      OR EXISTS (SELECT 1 FROM public.club_gestores pc WHERE pc.user_id = auth.uid() AND pc.activo)
$$;

CREATE OR REPLACE FUNCTION public.mis_roles() RETURNS jsonb
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'admin',       public.es_admin(),
    'club',        public.es_gestor_club(),
    'anunciante',  public.es_anunciante(),
    'clubes',      COALESCE((SELECT jsonb_agg(jsonb_build_object('club_id', pc.club_id, 'rol', pc.rol))
                               FROM public.club_gestores pc WHERE pc.user_id = auth.uid() AND pc.activo), '[]'::jsonb),
    'anunciantes', COALESCE((SELECT jsonb_agg(au.anunciante_id)
                               FROM public.anunciante_gestores au WHERE au.user_id = auth.uid() AND au.activo), '[]'::jsonb))
$$;

CREATE OR REPLACE FUNCTION public.sync_municipio_equipo() RETURNS trigger
  LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.equipo_id IS NOT NULL THEN
    SELECT municipio INTO NEW.municipio_equipo
    FROM equipos
    WHERE id = NEW.equipo_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_clubes_refrescar_equipos() RETURNS trigger
  LANGUAGE plpgsql SET search_path = public AS $$
begin
  if new.nombre is distinct from old.nombre or new.nombre_corto is distinct from old.nombre_corto then
    update public.equipos set nombre = nombre where club_id = new.id and nombre_auto;
  end if;
  return new;
end $$;

-- 3 · Vistas de compatibilidad con los nombres viejos (temporales)
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM _ren LOOP
    IF to_regclass('public.' || r.nuevo) IS NULL THEN CONTINUE; END IF;
    EXECUTE format('CREATE OR REPLACE VIEW public.%I WITH (security_invoker = true) AS SELECT * FROM public.%I', r.viejo, r.nuevo);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO anon, authenticated, service_role', r.viejo);
    EXECUTE format('COMMENT ON VIEW public.%I IS %L', r.viejo, 'Compatibilidad temporal: usar ' || r.nuevo);
  END LOOP;
END $$;

COMMIT;

-- Reversión: docs/migraciones/2026-11-14_REVERTIR_renombrar_tablas.sql
