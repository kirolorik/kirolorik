// Kirolorik · i18n.js · v1.1 · 2026-05-22
// Sistema de traducciones centralizado.
// Añadir un idioma nuevo = añadir un bloque más en I18N.
// Uso: t('key') → string en el idioma activo (var lang debe existir globalmente)
// Si la clave no existe en el idioma activo, cae a 'cas' (castellano = fallback).
// Si tampoco existe en 'cas', devuelve la propia clave (nunca rompe la página).

var I18N = {

  cas: {
    // —— Navegación / Chrome ——
    'nav.todos_deportes':      '🏅 Todos los deportes',
    'nav.todos_equipos':       '👕 Todos los equipos',
    'nav.municipios':          'Municipios',
    'nav.sel_municipio':       'Seleccionar municipio',
    'nav.todos_municipios':    'Todos los municipios',
    'nav.sin_filtro_ubi':      'Sin filtro de ubicación',

    // —— Grid / parrilla ——
    'grid.cargando':           'Cargando...',
    'grid.sin_eventos':        'Sin eventos próximos',
    'grid.sin_municipios':     'Sin municipios',
    'grid.ahora':              'Ahora',
    'grid.error':              'Error',

    // —— Leyenda ——
    'leg.entrada':             'Entrada',
    'leg.rifa':                'Rifa',
    'leg.gratis':              'Gratis',
    'leg.sin_icono':           'Sin icono = libre',

    // —— Badges de entrada ——
    'badge.entrada':           'Entrada',
    'badge.rifa':              'Rifa',
    'badge.gratis':            'Gratis',
    'badge.puertas':           'Puertas',

    // —— Detalle evento ——
    'det.titulo':              'Detalle',
    'det.fecha':               'Fecha',
    'det.instalacion':         'Instalación',
    'det.municipio':           'Municipio',
    'det.deporte':             'Deporte',
    'det.ver_maps':            'Ver en Google Maps →',
    'det.entrada_libre':       'Entrada libre',
    'det.entrada_pago':        'Entrada de pago',
    'det.entrada_rifa':        'Entrada con rifa',
    'det.puertas_abiertas':    'Puertas abiertas',
    'det.acceso_libre':        'Acceso libre al recinto',
    'det.ultima_act':          '* Última actualización:',
    'det.sobre_evento':        '📣 Sobre el evento',
    'det.cartel':              'Cartel',
    'det.participantes':        'Participantes',
    'det.evento_fallback':     'Evento',
    'det.hora_min':            'h · ~',
    'det.min':                 'min',

    // —— Perfil / Login ——
    'prof.invitado':           'Invitado',
    'prof.hola':               '¡Hola,',
    'prof.mi_perfil':          '👤 Mi perfil',
    'prof.gestionar':          '📋 Gestionar eventos',
    'prof.logout':             '🚿 A la ducha',
    'prof.email':              'Email',
    'prof.password':           'Password',
    'prof.entrar':             'Entra',
    'prof.recuperar_titulo':   'Recuperar contraseña',
    'prof.enviar_enlace':      'Enviar enlace ⚽',
    'prof.volver':             '← Volver',
    'prof.olvide':             '¿Olvidaste tu contraseña?',
    'prof.registrar_club':     '¿Quieres registrar tu club? kirolorik.info@gmail.com',
    'prof.error_campos':       'Rellena email y contraseña',
    'prof.placeholder_email':  'correo@ejemplo.com',
    'prof.check_correo':       'Revisa tu correo',

    // —— Publicidad ——
    'ad.tag':                  'Publicidad',
    'ad.espacio':              'Espacio publicitario',
    'ad.contactar':            'Contactar',

    // —— Footer legal ——
    'footer.privacidad':       'Privacidad',
    'footer.cookies':          'Cookies',
    'footer.rgpd':             'RGPD',
    'footer.terminos':         'Términos',
    'footer.publicidad':       'Publicidad',

    // —— Splash ——
    'splash.btn':              'Harmailetara! 🏟️',

    // —— Días y meses (ya existían, los centralizamos aquí también) ——
    'dias': ['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'],
    'meses': ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic']
  },

  eus: {
    // —— Navegación / Chrome ——
    'nav.todos_deportes':      '🏅 Kirol guztiak',
    'nav.todos_equipos':       '👕 Talde guztiak',
    'nav.municipios':          'Udalerriak',
    'nav.sel_municipio':       'Udalerria aukeratu',
    'nav.todos_municipios':    'Udalerri guztiak',
    'nav.sin_filtro_ubi':      'Kokapen-iragazkirik gabe',

    // —— Grid / parrilla ——
    'grid.cargando':           'Kargatzen...',
    'grid.sin_eventos':        'Ez dago gertaera hurbilik',
    'grid.sin_municipios':     'Udalerriak ez',
    'grid.ahora':              'Orain',
    'grid.error':              'Errorea',

    // —— Leyenda ——
    'leg.entrada':             'Sarrera',
    'leg.rifa':                'Zozketa',
    'leg.gratis':              'Doako',
    'leg.sin_icono':           'Ikonorik gabe = libre',

    // —— Badges de entrada ——
    'badge.entrada':           'Sarrera',
    'badge.rifa':              'Zozketa',
    'badge.gratis':            'Doako',
    'badge.puertas':           'Ateak',

    // —— Detalle evento ——
    'det.titulo':              'Xehetasunak',
    'det.fecha':               'Data',
    'det.instalacion':         'Instalazioa',
    'det.municipio':           'Udalerria',
    'det.deporte':             'Kirola',
    'det.ver_maps':            'Google Maps-en ikusi →',
    'det.entrada_libre':       'Sarrera librea',
    'det.entrada_pago':        'Ordainpeko sarrera',
    'det.entrada_rifa':        'Zozketa-sarrera',
    'det.puertas_abiertas':    'Ateak irekita',
    'det.acceso_libre':        'Eraikinera sarrera librea',
    'det.ultima_act':          '* Azken eguneraketa:',
    'det.sobre_evento':        '📣 Gertaerari buruz',
    'det.cartel':              'Kartela',
    'det.participantes':        'Parte-hartzaileak',
    'det.evento_fallback':     'Gertaera',
    'det.hora_min':            'h · ~',
    'det.min':                 'min',

    // —— Perfil / Login ——
    'prof.invitado':           'Gonbidatua',
    'prof.hola':               'Kaixo,',
    'prof.mi_perfil':          '👤 Nire profila',
    'prof.gestionar':          '📋 Gertaerak kudeatu',
    'prof.logout':             '🚿 Aldagelara',
    'prof.email':              'Email',
    'prof.password':           'Pasahitza',
    'prof.entrar':             'Sartu',
    'prof.recuperar_titulo':   'Pasahitza berreskuratu',
    'prof.enviar_enlace':      'Esteka bidali ⚽',
    'prof.volver':             '← Itzuli',
    'prof.olvide':             'Pasahitza ahaztu duzu?',
    'prof.registrar_club':     'Zure kluba erregistratu nahi duzu? kirolorik.info@gmail.com',
    'prof.error_campos':       'Bete email eta pasahitza',
    'prof.placeholder_email':  'helbidea@adibidea.com',
    'prof.check_correo':       'Egiaztatu zure posta',

    // —— Publicidad ——
    'ad.tag':                  'Publizitatea',
    'ad.espacio':              'Publizitate-tartea',
    'ad.contactar':            'Harremanetan jarri',

    // —— Footer legal ——
    'footer.privacidad':       'Pribatutasuna',
    'footer.cookies':          'Cookieak',
    'footer.rgpd':             'DBEO',
    'footer.terminos':         'Baldintzak',
    'footer.publicidad':       'Publizitatea',

    // —— Splash ——
    'splash.btn':              'Harmailetara! 🏟️',

    // —— Días y meses ——
    'dias': ['Ig','Al','Ar','Az','Og','Or','La'],
    'meses': ['Urt','Ots','Mar','Api','Mai','Eka','Uzt','Abu','Ira','Urr','Aza','Abe']
  }

  // Para añadir EN u otro idioma: copia el bloque 'cas', cambia las traducciones.
  // Las claves que falten caerán automáticamente a 'cas'.
};

/**
 * t(key) — devuelve la traducción en el idioma activo.
 * Nunca lanza error. Si la clave no existe, devuelve la propia clave.
 */
function t(key) {
  try {
    var activeLang = (typeof lang !== 'undefined' ? lang : 'cas') || 'cas';
    var block = I18N[activeLang] || I18N.cas;
    var val = block[key];
    if (val !== undefined) return val;
    // Fallback a castellano
    val = I18N.cas[key];
    if (val !== undefined) return val;
    // Fallback final: devuelve la clave (nunca undefined, nunca rompe)
    return key;
  } catch(e) {
    return key;
  }
}

/**
 * applyLang() — actualiza todos los elementos del DOM marcados con data-i18n.
 * Se llama desde changeLang() en index.html (y en cualquier otra página).
 * No toca lo que no está marcado → seguro para contenido dinámico de Supabase.
 */
function applyLang() {
  try {
    var els = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      var key = el.getAttribute('data-i18n');
      var attr = el.getAttribute('data-i18n-attr'); // p.ej. 'placeholder'
      var val = t(key);
      if (attr) {
        el.setAttribute(attr, val);
      } else {
        el.textContent = val;
      }
    }
  } catch(e) {}
}
