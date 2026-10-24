-- Kirolorik · clubes y equipos · parte B: datos (actualiza filas existentes) · 2026-10-24
-- Requiere la parte A. Propietario de los clubes nuevos: kirolorik.app@gmail.com

-- 1. Clubes nuevos para los equipos que no tenían club, a nombre del administrador
insert into public.clubes (nombre, municipio)
select v.n, 'Eibar' from (values ('Depor Xakea'), ('Depor Atletismoa')) v(n)
where not exists (select 1 from public.clubes c where c.nombre = v.n);

insert into public.perfil_club (user_id, club_id, rol)
select '785d1099-b544-4fcd-b6b9-3dbe33ee8a24', c.id, 'admin'
from public.clubes c
where c.nombre in ('Depor Xakea', 'Depor Atletismoa')
  and not exists (select 1 from public.perfil_club p where p.club_id = c.id and p.user_id = '785d1099-b544-4fcd-b6b9-3dbe33ee8a24');

update public.mis_equipos set club_id = (select id from public.clubes where nombre = 'Depor Xakea')
  where nombre = 'Depor Xakea' and club_id is null;
update public.mis_equipos set club_id = (select id from public.clubes where nombre = 'Depor Atletismoa'),
  user_id = '785d1099-b544-4fcd-b6b9-3dbe33ee8a24'
  where nombre = 'Depor Atletismoa' and club_id is null;
update public.mis_equipos set club_id = (select id from public.clubes where nombre = 'Kirolorik' limit 1)
  where nombre = 'Kirolorik FC' and club_id is null and activo;

-- 2. Deportes con los mismos valores que usa la app
update public.mis_equipos set deporte = case lower(deporte)
    when 'ajedréz' then 'ajedrez' when 'atletismoa' then 'atletismo' when 'billar' then 'billar'
    when 'trec' then 'trec' when 'triatlon' then 'triatlon' when 'gimnasia rítmica' then 'gimnasia ritmica' end
  where lower(deporte) in ('ajedréz', 'atletismoa', 'billar', 'trec', 'triatlon', 'gimnasia rítmica');
update public.eventos set deporte = case lower(deporte)
    when 'billar' then 'billar' when 'trec' then 'trec' when 'triatlon' then 'triatlon' when 'gimnasia rítmica' then 'gimnasia ritmica' end
  where lower(deporte) in ('billar', 'trec', 'triatlon', 'gimnasia rítmica');

-- 3. Nombres cortos de club
update public.clubes set nombre_corto = 'Urbat' where nombre = 'Urbat Waterpolo';
update public.clubes set nombre_corto = 'Eibar Rugby' where nombre = 'Eibar Rugby Taldea';
update public.clubes set nombre_corto = 'Casino Artista Eibarrés' where nombre = 'Club de billar Casino Artista Eibarrés';
update public.clubes set nombre_corto = 'Mugarra TT' where nombre = 'Mugarra Triatloi Taldea';

-- 4. División, nombre propio, tipo y categoría de cada equipo
update public.mis_equipos m
set division = v.division, nombre_propio = v.propio, tipo = v.tipo, categoria = coalesce(v.categoria, m.categoria)
from (values
  ('Eibar Eskubaloia B'::text,                       'B'::text,                       null::text,                   'equipo'::text,     null::text),
  ('Eibar Eskubaloia División Honor',                'División Honor',                null,                         'equipo',           null),
  ('Eibar Eskubaloia Liga Vasca',                    'Liga Vasca',                    null,                         'equipo',           null),
  ('Eibar Eskubaloia Primera Nacional',              'Primera Nacional',              null,                         'equipo',           null),
  ('Urbat Escolar',                                  'Escolar',                       null,                         'equipo',           null),
  ('Urbat Senior B Primera Euskal Herria',           'B Primera Euskal Herria',       null,                         'equipo',           null),
  ('Urbat Senior Segunda Nacional',                  'Segunda Nacional',              null,                         'equipo',           null),
  ('Hiru Urak Cadete Fem.',                          null,                            'Hiru Urak',                  'equipo',           null),
  ('Jagobe Mandiola - Teo',                          null,                            'Jagobe Mandiola - Teo',      'individual',       null),
  ('Kirolorik FC',                                   null,                            'Kirolorik FC',               'equipo',           null),
  ('Eibar Igerixan Absoluto',                        null,                            null,                         'equipo',           'Absoluto')
) as v(nombre, division, propio, tipo, categoria)
where m.nombre = v.nombre and m.activo;

-- 5. Club Ciclista Eibarrés es solo organizador: su evento pasa a organizador y su equipo se archiva
update public.eventos set organizador_id = (select id from public.clubes where nombre = 'Club Ciclista Eibarres'),
  equipo_id = null, equipo_local = null
  where equipo_id in (select id from public.mis_equipos where nombre = 'Club Ciclista Eibarres');
update public.mis_equipos set activo = false where nombre = 'Club Ciclista Eibarres';

-- 6. Se activa el nombre automático (el trigger recompone cada nombre y actualiza los eventos futuros)
update public.mis_equipos set nombre_auto = true where activo and club_id is not null;
