-- Proyecto: Kirolorik
-- Archivo: 2026-11-05_seguridad_rls.sql
-- Versión: v0.02
-- Fecha: 2026-11-04
-- Explicación: Migración correctiva de la auditoría de seguridad del 2026-11-05 (v0.01) revisada contra la BD real.
--   A. Recorta GRANTs excesivos (TRUNCATE/TRIGGER/REFERENCES y todo lo que anon no usa).
--   B. Evita suplantar clubes/equipos al crear o editar eventos y equipos.
--   C. Valida y limita inserciones anónimas (banner_clicks, errores, waitlist).
--   D. Cierra lecturas innecesarias (evento_views, tarifas ocultas, listado de storage).
-- Cambios respecto a v0.01:
--   * B2: se elimina también la política permisiva equipos_propios (ALL, user_id = auth.uid()); sin esto la restricción
--     de club no tenía efecto porque las políticas permisivas se suman.
--   * B2: el admin (kirolorik.app@gmail.com) puede escribir en cualquier equipo; sin esto no podría editar el club de prueba
--     «Kirolorik» (sus 3 equipos no tienen perfil_club del admin) y los triggers de refresco de nombres fallarían.
--   * B1: el UPDATE de eventos comprueba también equipo_id, igual que el INSERT.
-- PROBAR PRIMERO: ejecutar dentro de BEGIN ... ROLLBACK. Cada bloque es independiente.
-- Reversión: ver el final del archivo.

-- ============ A. GRANTs ============
REVOKE TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public FROM anon, authenticated;

-- anon solo necesita leer lo público y escribir métricas/formularios
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
GRANT SELECT ON public.eventos, public.clubes, public.mis_equipos, public.banners,
                public.faq, public.municipios, public.tarifas TO anon;
GRANT INSERT ON public.banner_clicks, public.evento_views, public.page_views,
                public.errores, public.waitlist TO anon;

-- anon no necesita secuencias de tablas en las que no inserta
REVOKE USAGE ON SEQUENCE public.eventos_id_seq, public.eventos_borrador_id_seq FROM anon;

-- ============ B. Suplantación de club / equipo ============
-- B1. eventos: organizador_id y equipo_id solo de clubes/equipos propios (INSERT y UPDATE)
DROP POLICY IF EXISTS escritura_autenticados ON public.eventos;
CREATE POLICY escritura_autenticados ON public.eventos
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.email() = 'kirolorik.app@gmail.com'
    OR (
      user_id = auth.uid()
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
CREATE POLICY edicion_propios ON public.eventos
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR auth.email() = 'kirolorik.app@gmail.com')
  WITH CHECK (
    auth.email() = 'kirolorik.app@gmail.com'
    OR (
      user_id = auth.uid()
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

-- B2. mis_equipos: no se puede colgar un equipo de un club ajeno
DROP POLICY IF EXISTS equipos_propios ON public.mis_equipos;
DROP POLICY IF EXISTS mis_equipos_write ON public.mis_equipos;
CREATE POLICY mis_equipos_write ON public.mis_equipos
  FOR ALL TO authenticated
  USING (
    auth.email() = 'kirolorik.app@gmail.com'
    OR user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.perfil_club pc
               WHERE pc.club_id = mis_equipos.club_id AND pc.user_id = auth.uid() AND pc.activo))
  WITH CHECK (
    auth.email() = 'kirolorik.app@gmail.com'
    OR (club_id IS NULL AND user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.perfil_club pc
               WHERE pc.club_id = mis_equipos.club_id AND pc.user_id = auth.uid() AND pc.activo)
  );

-- Política duplicada de lectura pública
DROP POLICY IF EXISTS equipos_lectura_publica ON public.mis_equipos;

-- ============ C. Inserciones anónimas ============
-- C1. clics solo sobre banners activos que existen (el antifraude real va en Edge Function)
DROP POLICY IF EXISTS insert_banner_clicks ON public.banner_clicks;
CREATE POLICY insert_banner_clicks ON public.banner_clicks
  FOR INSERT TO anon, authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.banners b WHERE b.id = banner_id AND b.activo));

-- C2. límites de tamaño/formato (tablas vacías hoy; si hubiera filas, usar NOT VALID)
ALTER TABLE public.errores
  ADD CONSTRAINT errores_longitudes CHECK (
    char_length(descripcion) <= 2000
    AND char_length(coalesce(email_contacto, '')) <= 254
    AND char_length(coalesce(pagina, '')) <= 200);
ALTER TABLE public.waitlist
  ADD CONSTRAINT waitlist_email_formato CHECK (
    char_length(email) <= 254 AND email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$');

-- ============ D. Lecturas innecesarias ============
-- D1. evento_views: cada usuario solo ve las visitas de sus eventos (admin ve todo)
DROP POLICY IF EXISTS read_evento_views ON public.evento_views;
CREATE POLICY read_evento_views ON public.evento_views
  FOR SELECT TO authenticated
  USING (
    auth.email() = 'kirolorik.app@gmail.com'
    OR EXISTS (SELECT 1 FROM public.eventos e WHERE e.id = evento_id AND e.user_id = auth.uid()));

-- D2. tarifas: no publicar planes ocultos / inactivos (ni stripe_price_id)
DROP POLICY IF EXISTS tarifas_publicas ON public.tarifas;
CREATE POLICY tarifas_publicas ON public.tarifas
  FOR SELECT TO anon, authenticated
  USING (activo AND visible);

-- D3. storage: los buckets son públicos, no hace falta permitir listar objetos
DROP POLICY IF EXISTS lectura_publica_storage  ON storage.objects;
DROP POLICY IF EXISTS lectura_publica_escudos  ON storage.objects;
DROP POLICY IF EXISTS lectura_publica_banners  ON storage.objects;

-- ============ REVERSIÓN (por si algo falla tras aplicar) ============
-- A: GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;   -- vuelve al estado anterior
-- B2: CREATE POLICY equipos_propios ON public.mis_equipos FOR ALL TO public USING (auth.uid() = user_id);
-- D3: CREATE POLICY lectura_publica_storage ON storage.objects FOR SELECT TO public USING (bucket_id = 'eventos');
--     CREATE POLICY lectura_publica_escudos ON storage.objects FOR SELECT TO public USING (bucket_id = 'escudos');
--     CREATE POLICY lectura_publica_banners ON storage.objects FOR SELECT TO public USING (bucket_id = 'banners');
-- D1: CREATE POLICY read_evento_views ON public.evento_views FOR SELECT TO authenticated USING (true);
-- D2: CREATE POLICY tarifas_publicas ON public.tarifas FOR SELECT TO public USING (true);
