-- Proyecto: Kirolorik
-- Archivo: docs/migraciones/2026-11-14b_quitar_vistas_compat.sql
-- Versión: v0.01 · 2026-11-14
-- Descripción: elimina las vistas de compatibilidad con los nombres antiguos creadas por 2026-11-14_renombrar_tablas.sql.
--   Ejecutar SOLO cuando el código nuevo esté fusionado/publicado y la función admin-users redesplegada.
-- Reversión: volver a crear las vistas (bloque 3 de 2026-11-14_renombrar_tablas.sql).
BEGIN;
DROP VIEW IF EXISTS public.perfil_club, public.mis_equipos, public.anunciante_usuarios, public.facturas,
  public.solicitudes_pueblo, public.disenos_banner, public.page_views, public.evento_views, public.perfiles;
COMMIT;
