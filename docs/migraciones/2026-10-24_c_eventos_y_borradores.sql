-- Kirolorik · clubes y equipos · parte C: organizador en borradores, deportes y enlace de eventos · 2026-10-24
-- Requiere las partes A y B.

-- 1. Los borradores pueden llevar el club organizador
alter table public.eventos_borrador add column if not exists organizador_id uuid;

-- 2. Deporte con el mismo valor que usa la app
update public.eventos set deporte = 'trail' where deporte = 'Trail';

-- 3. Eventos que todavía llevan el nombre antiguo de un equipo renombrado (de ayer en adelante)
update public.eventos e set equipo_local = v.nuevo
from (values
  ('Urbat Infantil Mix.', 'Urbat Infantil'),
  ('Urbat Senior Fem.', 'Urbat Fem.'),
  ('Urbat Senior Segunda Nacional', 'Urbat Segunda Nacional'),
  ('Urbat Senior B Primera Euskal Herria', 'Urbat B Primera Euskal Herria'),
  ('Eibar Igerixan Benjamin', 'Eibar Igerixan Benjamín')
) v(viejo, nuevo)
where e.equipo_local = v.viejo and e.fecha >= current_date - 1;

update public.eventos e set equipo_visitante = v.nuevo
from (values
  ('Urbat Infantil Mix.', 'Urbat Infantil'),
  ('Urbat Senior Fem.', 'Urbat Fem.'),
  ('Urbat Senior Segunda Nacional', 'Urbat Segunda Nacional'),
  ('Urbat Senior B Primera Euskal Herria', 'Urbat B Primera Euskal Herria'),
  ('Eibar Igerixan Benjamin', 'Eibar Igerixan Benjamín')
) v(viejo, nuevo)
where e.equipo_visitante = v.viejo and e.fecha >= current_date - 1;

-- 4. Enlazar por nombre exacto los eventos que solo tenían el equipo como texto (solo si el nombre es único entre los equipos activos)
update public.eventos e set equipo_id = m.id
from public.mis_equipos m
where e.equipo_id is null and e.equipo_local = m.nombre and m.activo and m.club_id is not null
  and (select count(*) from public.mis_equipos x where x.activo and x.nombre = m.nombre) = 1;

update public.eventos e set equipo_visitante_id = m.id
from public.mis_equipos m
where e.equipo_visitante_id is null and e.equipo_visitante = m.nombre and m.activo and m.club_id is not null
  and (select count(*) from public.mis_equipos x where x.activo and x.nombre = m.nombre) = 1;

-- 5. Los eventos de ayer en adelante toman el nombre actual de su equipo
update public.eventos e set equipo_local = m.nombre
from public.mis_equipos m
where e.equipo_id = m.id and e.fecha >= current_date - 1 and e.equipo_local is distinct from m.nombre;

update public.eventos e set equipo_visitante = m.nombre
from public.mis_equipos m
where e.equipo_visitante_id = m.id and e.fecha >= current_date - 1 and e.equipo_visitante is distinct from m.nombre;
