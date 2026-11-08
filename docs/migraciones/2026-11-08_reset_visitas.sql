-- Proyecto: Kirolorik
-- Archivo: 2026-11-08_reset_visitas.sql
-- Versión: v0.01
-- Fecha: 2026-11-08
-- Explicación: Pone a cero las estadísticas de visitas (page_views, evento_views) y las de banners (banner_clicks y
--   banner_metricas_diarias), contaminadas por las pruebas del equipo. ANTES de borrar guarda una copia en tablas bak_*
--   (sin acceso desde la API) por si hubiera que recuperar algo. Ejecutar cuando la portada v6.45 (que ya no cuenta las
--   visitas de quien tiene sesión ni de sus dispositivos) esté desplegada.
-- Si NO quieres resetear alguna estadística, borra o comenta sus dos líneas (copia y borrado).

-- 1. Copia de seguridad (se pueden borrar cuando quieras con DROP TABLE)
CREATE TABLE public.bak_page_views_20261108              AS TABLE public.page_views;
CREATE TABLE public.bak_evento_views_20261108            AS TABLE public.evento_views;
CREATE TABLE public.bak_banner_clicks_20261108           AS TABLE public.banner_clicks;
CREATE TABLE public.bak_banner_metricas_diarias_20261108 AS TABLE public.banner_metricas_diarias;

-- Las copias no deben ser accesibles desde la API pública: RLS activado sin políticas y sin permisos para los roles de la API
ALTER TABLE public.bak_page_views_20261108              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bak_evento_views_20261108            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bak_banner_clicks_20261108           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bak_banner_metricas_diarias_20261108 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bak_page_views_20261108, public.bak_evento_views_20261108,
              public.bak_banner_clicks_20261108, public.bak_banner_metricas_diarias_20261108 FROM anon, authenticated;

-- 2. Reseteo
DELETE FROM public.page_views;
DELETE FROM public.evento_views;
DELETE FROM public.banner_clicks;
DELETE FROM public.banner_metricas_diarias;

-- 3. Comprobación: las cuatro tablas a 0 y las copias con lo que había
SELECT (SELECT count(*) FROM public.page_views)              AS page_views,
       (SELECT count(*) FROM public.evento_views)            AS evento_views,
       (SELECT count(*) FROM public.banner_clicks)           AS banner_clicks,
       (SELECT count(*) FROM public.banner_metricas_diarias) AS metricas,
       (SELECT count(*) FROM public.bak_page_views_20261108)              AS copia_page_views,
       (SELECT count(*) FROM public.bak_evento_views_20261108)            AS copia_evento_views,
       (SELECT count(*) FROM public.bak_banner_clicks_20261108)           AS copia_banner_clicks,
       (SELECT count(*) FROM public.bak_banner_metricas_diarias_20261108) AS copia_metricas;

-- REVERSIÓN (volver a poner lo que había):
-- INSERT INTO public.page_views              SELECT * FROM public.bak_page_views_20261108;
-- INSERT INTO public.evento_views            SELECT * FROM public.bak_evento_views_20261108;
-- INSERT INTO public.banner_clicks           SELECT * FROM public.bak_banner_clicks_20261108;
-- INSERT INTO public.banner_metricas_diarias SELECT * FROM public.bak_banner_metricas_diarias_20261108;
