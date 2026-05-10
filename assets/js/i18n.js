// ═══════════════════════════════════════
// KIROLORIK · i18n.js
// Gestor de traducciones
// Los idiomas se cargan desde /assets/locales/xx.js
// Cada archivo registra sus traducciones en window.KIRO_L.xx
// ═══════════════════════════════════════

window.KIRO_L = window.KIRO_L || {};

// Obtener traducción
function kT(key, lang) {
  var l = window.KIRO_L[lang];
  if (l && l[key] !== undefined) return l[key];
  // Fallback a castellano
  var f = window.KIRO_L.cas;
  if (f && f[key] !== undefined) return f[key];
  return key;
}

// Obtener array de días/meses
function kDias(lang) {
  var l = window.KIRO_L[lang];
  return (l && l.dias) || ['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'];
}

function kMeses(lang) {
  var l = window.KIRO_L[lang];
  return (l && l.meses) || ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
}
