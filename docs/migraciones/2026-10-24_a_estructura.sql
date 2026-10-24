-- Kirolorik · clubes y equipos · parte A: estructura (solo añade, no borra nada) · 2026-10-24

-- Copias de seguridad privadas (sin acceso desde la API) antes de tocar datos
create table if not exists public.mis_equipos_backup_20261024 as table public.mis_equipos;
create table if not exists public.eventos_backup_20261024 as
  select id, equipo_id, equipo_visitante_id, equipo_local, equipo_visitante, deporte, municipio_equipo from public.eventos;
alter table public.mis_equipos_backup_20261024 enable row level security;
alter table public.eventos_backup_20261024 enable row level security;
revoke all on public.mis_equipos_backup_20261024 from anon, authenticated;
revoke all on public.eventos_backup_20261024 from anon, authenticated;

alter table public.clubes add column if not exists nombre_corto text;

alter table public.mis_equipos
  add column if not exists division text,
  add column if not exists nombre_propio text,
  add column if not exists tipo text not null default 'equipo',
  add column if not exists nombre_auto boolean not null default false;
alter table public.mis_equipos drop constraint if exists mis_equipos_tipo_check;
alter table public.mis_equipos add constraint mis_equipos_tipo_check check (tipo in ('equipo','individual'));

alter table public.eventos add column if not exists organizador_id uuid references public.clubes(id) on delete set null;
create index if not exists eventos_organizador_id_idx on public.eventos (organizador_id);

-- Nombre completo de un equipo: base (nombre propio, nombre corto del club o nombre del club)
-- + división; o, sin división, categoría (menos Senior/Élite/Todas) + género (Masc./Fem.; Mixto no lleva sufijo).
-- Un individual muestra solo su nombre propio.
create or replace function public.componer_nombre_equipo(
  p_club_id uuid, p_nombre_propio text, p_categoria text, p_division text, p_genero text, p_tipo text, p_actual text
) returns text language plpgsql stable set search_path = public as $$
declare
  v_club text; v_corto text; v_base text; v_res text;
begin
  select nombre, nombre_corto into v_club, v_corto from public.clubes where id = p_club_id;
  v_base := coalesce(nullif(trim(p_nombre_propio), ''), nullif(trim(v_corto), ''), nullif(trim(v_club), ''), p_actual);
  if p_tipo = 'individual' then return v_base; end if;
  v_res := v_base;
  if nullif(trim(p_division), '') is not null then
    v_res := v_res || ' ' || trim(p_division);
  else
    if p_categoria is not null and p_categoria not in ('Senior', 'Élite', 'Todas') then
      v_res := v_res || ' ' || case p_categoria when 'Master' then 'Máster' else p_categoria end;
    end if;
    if p_genero = 'Masculino' then v_res := v_res || ' Masc.';
    elsif p_genero = 'Femenino' then v_res := v_res || ' Fem.';
    end if;
  end if;
  return v_res;
end $$;

-- El nombre se recompone solo en los equipos con nombre_auto = true
create or replace function public.trg_mis_equipos_nombre() returns trigger language plpgsql set search_path = public as $$
begin
  if new.nombre_auto then
    new.nombre := public.componer_nombre_equipo(new.club_id, new.nombre_propio, new.categoria, new.division, new.genero, new.tipo, new.nombre);
  end if;
  return new;
end $$;
drop trigger if exists mis_equipos_nombre on public.mis_equipos;
create trigger mis_equipos_nombre before insert or update on public.mis_equipos
  for each row execute function public.trg_mis_equipos_nombre();

-- Si cambia el nombre de un club, se refrescan los nombres de sus equipos automáticos
create or replace function public.trg_clubes_refrescar_equipos() returns trigger language plpgsql set search_path = public as $$
begin
  if new.nombre is distinct from old.nombre or new.nombre_corto is distinct from old.nombre_corto then
    update public.mis_equipos set nombre = nombre where club_id = new.id and nombre_auto;
  end if;
  return new;
end $$;
drop trigger if exists clubes_refrescar_equipos on public.clubes;
create trigger clubes_refrescar_equipos after update on public.clubes
  for each row execute function public.trg_clubes_refrescar_equipos();

-- Si cambia el nombre de un equipo, los eventos futuros que lo usan toman el nombre nuevo (los pasados se quedan como estaban)
create or replace function public.trg_mis_equipos_eventos() returns trigger language plpgsql set search_path = public as $$
begin
  if new.nombre is distinct from old.nombre then
    update public.eventos set equipo_local = new.nombre where equipo_id = new.id and fecha >= current_date;
    update public.eventos set equipo_visitante = new.nombre where equipo_visitante_id = new.id and fecha >= current_date;
  end if;
  return new;
end $$;
drop trigger if exists mis_equipos_eventos on public.mis_equipos;
create trigger mis_equipos_eventos after update of nombre on public.mis_equipos
  for each row execute function public.trg_mis_equipos_eventos();
