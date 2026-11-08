-- Proyecto: Kirolorik
-- Archivo: 2026-11-13_roles.sql
-- Versión: v0.01
-- Fecha: 2026-11-13
-- Explicación: Separación de roles en la base de datos (paso 1 de separar admin, clubes y anunciantes).
--   Hasta ahora cualquier usuario con sesión (por ejemplo un anunciante) podía crear eventos públicos y equipos, y subir imágenes de
--   eventos y escudos. Desde ahora esas operaciones exigen ser ADMIN o GESTOR DE CLUB (tener un perfil de club activo).
--   Un usuario sigue siendo uno solo (auth.users); su rol sale de las tablas de vínculo:
--     · gestor de club  → perfil_club (activo)
--     · anunciante      → anunciante_usuarios (activo)
--     · admin           → la cuenta kirolorik.app@gmail.com
--   Una misma persona puede tener varios roles. Funciones nuevas: es_gestor_club(), es_anunciante() y mis_roles() (para que cada
--   página compruebe qué es el usuario). Requiere las migraciones 2026-11-08 y 2026-11-11. Reversión al final.

-- ============ Funciones de rol ============
CREATE OR REPLACE FUNCTION public.es_gestor_club() RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.es_admin()
      OR EXISTS (SELECT 1 FROM public.perfil_club pc WHERE pc.user_id = auth.uid() AND pc.activo)
$$;
CREATE OR REPLACE FUNCTION public.es_anunciante() RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.anunciante_usuarios au WHERE au.user_id = auth.uid() AND au.activo)
$$;
-- Qué es el usuario actual (para las guardias de cada página)
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
REVOKE ALL ON FUNCTION public.es_gestor_club(), public.es_anunciante(), public.mis_roles() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.es_gestor_club(), public.es_anunciante(), public.mis_roles() TO authenticated;

-- ============ Eventos: solo admin o gestor de club ============
DROP POLICY IF EXISTS escritura_autenticados ON public.eventos;
CREATE POLICY escritura_autenticados ON public.eventos FOR INSERT TO authenticated
  WITH CHECK (
    public.es_admin()
    OR (
      public.es_gestor_club() AND user_id = auth.uid()
      AND (organizador_id IS NULL OR EXISTS (
            SELECT 1 FROM public.perfil_club pc
            WHERE pc.club_id = organizador_id AND pc.user_id = auth.uid() AND pc.activo))
      AND (equipo_id IS NULL OR EXISTS (
            SELECT 1 FROM public.mis_equipos m
            WHERE m.id = equipo_id AND (m.user_id = auth.uid() OR EXISTS (
                  SELECT 1 FROM public.perfil_club pc
                  WHERE pc.club_id = m.club_id AND pc.user_id = auth.uid() AND pc.activo))))
    )
  );

DROP POLICY IF EXISTS edicion_propios ON public.eventos;
CREATE POLICY edicion_propios ON public.eventos FOR UPDATE TO authenticated
  USING (public.es_admin() OR (user_id = auth.uid() AND public.es_gestor_club()))
  WITH CHECK (
    public.es_admin()
    OR (
      public.es_gestor_club() AND user_id = auth.uid()
      AND (organizador_id IS NULL OR EXISTS (
            SELECT 1 FROM public.perfil_club pc
            WHERE pc.club_id = organizador_id AND pc.user_id = auth.uid() AND pc.activo))
      AND (equipo_id IS NULL OR EXISTS (
            SELECT 1 FROM public.mis_equipos m
            WHERE m.id = equipo_id AND (m.user_id = auth.uid() OR EXISTS (
                  SELECT 1 FROM public.perfil_club pc
                  WHERE pc.club_id = m.club_id AND pc.user_id = auth.uid() AND pc.activo))))
    )
  );

DROP POLICY IF EXISTS borrado_propios ON public.eventos;
CREATE POLICY borrado_propios ON public.eventos FOR DELETE TO authenticated
  USING (public.es_admin() OR (user_id = auth.uid() AND public.es_gestor_club()));

-- ============ Equipos: solo admin o gestor de club ============
DROP POLICY IF EXISTS mis_equipos_write ON public.mis_equipos;
CREATE POLICY mis_equipos_write ON public.mis_equipos FOR ALL TO authenticated
  USING (
    public.es_admin()
    OR (public.es_gestor_club() AND (
          user_id = auth.uid()
          OR EXISTS (SELECT 1 FROM public.perfil_club pc
                     WHERE pc.club_id = mis_equipos.club_id AND pc.user_id = auth.uid() AND pc.activo)))
  )
  WITH CHECK (
    public.es_admin()
    OR (public.es_gestor_club() AND (
          (club_id IS NULL AND user_id = auth.uid())
          OR EXISTS (SELECT 1 FROM public.perfil_club pc
                     WHERE pc.club_id = mis_equipos.club_id AND pc.user_id = auth.uid() AND pc.activo)))
  );

-- ============ Imágenes de eventos y escudos: solo admin o gestor de club ============
DROP POLICY IF EXISTS subida_autenticados ON storage.objects;            -- bucket eventos
CREATE POLICY subida_eventos_gestores ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'eventos' AND public.es_gestor_club());
DROP POLICY IF EXISTS subida_escudos_autenticados ON storage.objects;    -- bucket escudos
CREATE POLICY subida_escudos_gestores ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'escudos' AND public.es_gestor_club());

-- ============ REVERSIÓN ============
-- Políticas anteriores (cualquier usuario con sesión):
-- DROP POLICY subida_eventos_gestores ON storage.objects; DROP POLICY subida_escudos_gestores ON storage.objects;
-- CREATE POLICY subida_autenticados ON storage.objects FOR INSERT TO public WITH CHECK (bucket_id='eventos' AND auth.role()='authenticated');
-- CREATE POLICY subida_escudos_autenticados ON storage.objects FOR INSERT TO public WITH CHECK (bucket_id='escudos' AND auth.role()='authenticated');
-- y restaurar escritura_autenticados / edicion_propios / borrado_propios / mis_equipos_write desde 2026-11-05_seguridad_rls.sql
-- DROP FUNCTION public.mis_roles(); DROP FUNCTION public.es_anunciante(); DROP FUNCTION public.es_gestor_club();
