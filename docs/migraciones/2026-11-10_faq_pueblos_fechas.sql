-- Proyecto: Kirolorik
-- Archivo: 2026-11-10_faq_pueblos_fechas.sql
-- Versión: v0.01
-- Fecha: 2026-11-10
-- Explicación: FAQ de anunciantes (categoría «publicidad»): qué banners salen con «Todos los municipios», qué pasa si el pueblo no
--   tiene anunciantes, cómo pedir un pueblo nuevo y cuándo empieza y acaba un banner.
-- Reversión: DELETE FROM public.faq WHERE categoria = 'publicidad' AND orden IN (120,130,140,150);

INSERT INTO public.faq (categoria, pregunta, respuesta, orden, activo) VALUES
('publicidad', '¿Qué banners se ven si se elige «Todos los municipios»?',
 'Solo los banners marcados para todos los pueblos. Los banners de un pueblo concreto únicamente se muestran cuando ese pueblo está elegido; así se respeta la exclusividad por tipo de negocio en cada pueblo.', 120, true),
('publicidad', '¿Y si en el pueblo del partido no hay anunciantes?',
 'Si el pueblo elegido no tiene ningún anunciante propio, se muestran los de los pueblos de los equipos visitantes de los partidos que se ven (por ejemplo, un partido en Donosti contra un equipo de Eibar muestra los anunciantes de Eibar). Los banners de «todos los pueblos» salen siempre.', 130, true),
('publicidad', 'Mi pueblo no aparece en la lista, ¿qué hago?',
 'Escríbenos a kirolorik.info@gmail.com y lo añadimos. (Próximamente podrás solicitarlo desde tu zona de anunciantes.) El pueblo aparece en el selector de la portada cuando tiene eventos.', 140, true),
('publicidad', '¿Cuándo empieza y cuándo termina mi banner?',
 'Las fechas se fijan al aprobar tu contrato: empieza cuando lo aprobamos (o en la fecha que acordemos) y dura lo que el plan elegido: mensual, trimestral o anual. Si quieres otro pueblo u otras fechas, es un contrato nuevo.', 150, true);
