/* Kirolorik · zona.js · v1.00 · 2026-11-15
   Parte común de las zonas privadas (clubes y anunciantes): inicio de sesión y recuperación de contraseña, sesión que se renueva sola,
   comprobación del rol (mis_roles), cabecera con flecha y título, ficha de la persona, Datos personales (nombre, teléfono, idioma,
   email, contraseña y avisos por correo), Sesión (última conexión, ayuda y cerrar sesión), Zona de riesgo (baja de cuenta) y pantallas
   internas (data-vista) con el botón «atrás» del navegador. Necesita sesion.js y zona.css.
   Uso: KBZ.iniciar({zona,grupo,inicio,titulo,sb,key,permiso,sinPermiso,textoBaja,alEntrar}) y, en la página, los contenedores
   #z-acceso, #z-app, #z-hdr, #z-hero, #z-datos, #z-sesion y #z-riesgo; las pantallas son elementos con data-vista="nombre"
   (data-titulo="Título") y las filas que las abren llevan data-z="vista:nombre". */
var KBZ=(function(){
  var W=window, D=document, C={}, tok=null, user=null, perfil=null, roles=null;
  var _fetch=W.fetch.bind(W), refrescando=null, actual='principal', empujado=false, bajando=false;
  var COLORS=['#1a6bff','#16a34a','#dc2626','#9333ea','#ea580c','#0891b2','#db2777'];

  function $(id){ return D.getElementById(id); }
  function esc(s){ if(s==null) return ''; return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
  function G(k){ return C.grupo+'_'+k; }
  function jwtExp(t){ try{ return JSON.parse(atob(String(t).split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).exp*1000; }catch(e){ return 0; } }
  function H(){ return {'apikey':C.key,'Authorization':'Bearer '+(tok||C.key),'Content-Type':'application/json'}; }
  function val(id){ var e=$(id); return e?e.value.trim():''; }
  function color(e){ return COLORS[(e||'').charCodeAt(0)%COLORS.length]; }
  var tt=null;
  function toast(msg,tipo){
    var t=$('z-toast'); if(!t) return;
    t.textContent=msg; t.className='z-toast show'+(tipo?' '+tipo:'');
    clearTimeout(tt); tt=setTimeout(function(){ t.className='z-toast'; },3200);
  }

  // ── Sesión que se renueva sola ──
  function refrescar(){
    if(refrescando) return refrescando;
    refrescando=KBS.lock(G('refresh'),function(){
      var tk=KBS.get(G('token'));
      if(tk&&tk!==tok&&jwtExp(tk)-Date.now()>60000){ tok=tk; try{ user=JSON.parse(KBS.get(G('user'))||'null')||user; }catch(e){} return true; }
      var rt=KBS.get(G('refresh')); if(!rt) return false;
      return _fetch(C.sb+'/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{'apikey':C.key,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:rt})})
        .then(function(r){ return r.ok?r.json():null; }).then(function(d){
          if(!d||!d.access_token) return false;
          tok=d.access_token; KBS.set(G('token'),tok);
          if(d.refresh_token) KBS.set(G('refresh'),d.refresh_token);
          if(d.user){ user=d.user; KBS.set(G('user'),JSON.stringify(d.user)); }
          return true;
        });
    }).catch(function(){ return false; }).then(function(ok){ refrescando=null; return ok; });
    return refrescando;
  }
  W.fetch=function(url,opts){
    return _fetch(url,opts).then(function(res){
      if(res.status!==401||!tok||!C.sb||typeof url!=='string'||url.indexOf(C.sb)!==0||url.indexOf('/auth/v1/')>=0) return res;
      return refrescar().then(function(ok){
        if(!ok){ caducada(); return res; }
        var o=Object.assign({},opts||{}); o.headers=Object.assign({},o.headers||{},{'Authorization':'Bearer '+tok});
        return _fetch(url,o);
      });
    });
  };
  setInterval(function(){ if(tok&&jwtExp(tok)-Date.now()<5*60000) refrescar(); },60000);
  D.addEventListener('visibilitychange',function(){ if(!D.hidden&&tok&&jwtExp(tok)-Date.now()<5*60000) refrescar(); });
  function caducada(){
    KBS.clear(C.grupo); tok=null; user=null;
    var a=$('z-app'); if(a) a.style.display='none';
    acceso('login'); var e=$('z-login-err'); if(e){ e.style.color='#dc2626'; e.textContent='La sesión ha caducado. Entra de nuevo.'; }
  }

  // ── Acceso ──
  function htmlAcceso(){
    return ''
    +'<div id="z-p-login" style="display:none;flex-direction:column;align-items:center;gap:14px;width:100%">'
    +  '<div class="z-logo">KIROLORIK</div><div class="z-logo-sub">'+esc(C.titulo)+'</div>'
    +  '<div class="z-caja">'
    +    '<div class="z-field" style="margin:0"><label>Email</label><input type="email" id="z-email" autocomplete="username"></div>'
    +    '<div class="z-field" style="margin:0"><label>Contraseña</label><input type="password" id="z-pass" autocomplete="current-password"></div>'
    +    '<label style="display:flex;align-items:center;gap:8px;font-size:13px;cursor:pointer"><input type="checkbox" id="z-recordar" checked style="width:auto;margin:0"> Mantener sesión iniciada</label>'
    +    '<div class="z-err" id="z-login-err"></div>'
    +    '<button class="z-btn" id="z-login-btn" data-z="login">Entrar</button>'
    +    '<button class="z-link" data-z="rec-mostrar">¿Has olvidado la contraseña?</button>'
    +    '<div class="z-nota">¿Aún no tienes acceso? Escríbenos a <a href="mailto:kirolorik.info@gmail.com">kirolorik.info@gmail.com</a></div>'
    +    '<div class="z-nota"><a href="/">← Volver al inicio</a></div>'
    +  '</div></div>'
    +'<div id="z-p-rec" style="display:none;flex-direction:column;align-items:center;gap:14px;width:100%">'
    +  '<div class="z-logo">KIROLORIK</div><div class="z-logo-sub">'+esc(C.titulo)+'</div>'
    +  '<div class="z-caja"><div style="font-size:14px;font-weight:700">Recuperar contraseña</div>'
    +    '<div class="z-field" style="margin:0"><label>Email</label><input type="email" id="z-rec-email"></div>'
    +    '<div id="z-rec-msg" style="font-size:12px;min-height:16px"></div>'
    +    '<button class="z-btn" id="z-rec-btn" data-z="rec-enviar">Enviar enlace</button>'
    +    '<button class="z-link" data-z="login-mostrar">← Volver</button></div></div>'
    +'<div id="z-p-new" style="display:none;flex-direction:column;align-items:center;gap:14px;width:100%">'
    +  '<div class="z-logo">KIROLORIK</div><div class="z-logo-sub">'+esc(C.titulo)+'</div>'
    +  '<div class="z-caja"><div style="font-size:14px;font-weight:700">Elige una contraseña nueva</div>'
    +    '<div class="z-field" style="margin:0"><label>Contraseña nueva (mín. 8 caracteres)</label><input type="password" id="z-np1" autocomplete="new-password"></div>'
    +    '<div class="z-field" style="margin:0"><label>Repítela</label><input type="password" id="z-np2" autocomplete="new-password"></div>'
    +    '<div id="z-np-msg" style="font-size:12px;min-height:16px;color:#dc2626"></div>'
    +    '<button class="z-btn" id="z-np-btn" data-z="np-guardar">Guardar contraseña</button></div></div>'
    +'<div id="z-p-sinperm" style="display:none;flex-direction:column;align-items:center;gap:12px;width:100%">'
    +  '<div class="z-ico">🔒</div><div class="z-acc-title">'+esc(C.sinPermisoTitulo||'Esta cuenta no tiene acceso a esta zona')+'</div>'
    +  '<div class="z-acc-txt">'+(C.sinPermiso||'')+'</div>'
    +  '<button class="z-btn" style="max-width:240px" data-z="salir">Cerrar sesión</button></div>';
  }
  function acceso(cual){
    var a=$('z-acceso'); if(!a) return;
    a.style.display='flex';
    ['login','rec','new','sinperm'].forEach(function(p){ var e=$('z-p-'+p); if(e) e.style.display=(p===cual)?'flex':'none'; });
    var app=$('z-app'); if(app) app.style.display='none';
  }
  function hashRecuperacion(){
    var h=location.hash.replace(/^#/,''); if(!h) return null;
    var p={}; h.split('&').forEach(function(x){ var kv=x.split('='); p[kv[0]]=decodeURIComponent(kv[1]||''); });
    return (p.type==='recovery'&&p.access_token)?p.access_token:null;
  }
  async function login(){
    var email=val('z-email'), pass=$('z-pass').value, err=$('z-login-err'), btn=$('z-login-btn');
    err.style.color='#dc2626'; err.textContent='';
    if(!email||!pass){ err.textContent='Escribe tu email y tu contraseña'; return; }
    btn.disabled=true; btn.textContent='...';
    try{
      var res=await fetch(C.sb+'/auth/v1/token?grant_type=password',{method:'POST',headers:{'apikey':C.key,'Content-Type':'application/json'},body:JSON.stringify({email:email,password:pass})});
      var d=await res.json(); if(!res.ok) throw new Error(d.error_description||'Email o contraseña incorrectos');
      tok=d.access_token; user=d.user;
      KBS.setPersist(!!$('z-recordar').checked,C.grupo);
      KBS.set(G('token'),tok); KBS.set(G('user'),JSON.stringify(user)); if(d.refresh_token) KBS.set(G('refresh'),d.refresh_token);
      btn.disabled=false; btn.textContent='Entrar';
      entrar();
    }catch(e){ err.textContent=e.message; btn.disabled=false; btn.textContent='Entrar'; }
  }
  async function recEnviar(){
    var email=val('z-rec-email'), msg=$('z-rec-msg'), btn=$('z-rec-btn');
    if(!email){ msg.style.color='#dc2626'; msg.textContent='Escribe tu email'; return; }
    btn.disabled=true;
    try{
      await fetch(C.sb+'/auth/v1/recover',{method:'POST',headers:{'apikey':C.key,'Content-Type':'application/json'},body:JSON.stringify({email:email,redirect_to:W.location.origin+C.inicio})});
      msg.style.color='#16a34a'; msg.textContent='Si el email existe, recibirás un enlace para elegir una contraseña nueva.';
    }catch(e){ msg.style.color='#dc2626'; msg.textContent='No se ha podido enviar. Inténtalo de nuevo.'; }
    btn.disabled=false;
  }
  async function npGuardar(){
    var a=$('z-np1').value, b=$('z-np2').value, msg=$('z-np-msg'), btn=$('z-np-btn');
    if(a.length<8){ msg.textContent='La contraseña debe tener al menos 8 caracteres'; return; }
    if(a!==b){ msg.textContent='Las contraseñas no coinciden'; return; }
    btn.disabled=true;
    try{
      var res=await _fetch(C.sb+'/auth/v1/user',{method:'PUT',headers:{'apikey':C.key,'Authorization':'Bearer '+W._tokenRecuperacion,'Content-Type':'application/json'},body:JSON.stringify({password:a})});
      var d=await res.json(); if(!res.ok) throw new Error(d.msg||d.error_description||'No se ha podido guardar la contraseña');
      history.replaceState(null,'',location.pathname+location.search); W._tokenRecuperacion=null;
      acceso('login'); var e=$('z-login-err'); e.style.color='#16a34a'; e.textContent='Contraseña guardada. Ya puedes entrar.';
    }catch(e){ msg.textContent=e.message; }
    btn.disabled=false;
  }
  function salir(){ KBS.cerrar(C.sb,C.key,C.grupo,function(){ W.location.href=C.inicio; }); }

  // ── Perfil de la persona ──
  function nombreMostrado(){
    var em=(user&&user.email)||'';
    return (perfil&&(perfil.nombre||perfil.alias))||em.split('@')[0];
  }
  function pintarPerfil(){
    var em=(user&&user.email)||'', nom=nombreMostrado();
    var av=$('z-avatar'); if(av){ av.textContent=(nom||em).charAt(0).toUpperCase(); av.style.background=color(em); }
    var n=$('z-hero-name'); if(n) n.textContent=nom;
    var f=function(id,t){ var e=$(id); if(e) e.textContent=t; };
    f('z-v-nombre',(perfil&&perfil.nombre)||'—');
    f('z-v-tel',(perfil&&perfil.telefono)||'—');
    f('z-v-idioma',((perfil&&perfil.idioma)||'cas').toUpperCase());
    f('z-v-avisos',(!perfil||perfil.avisos_email!==false)?'Sí':'No');
  }
  async function cargarPerfil(){
    try{
      var res=await fetch(C.sb+'/rest/v1/usuarios_perfil?id=eq.'+encodeURIComponent(user.id)+'&select=*',{headers:H()});
      var d=await res.json();
      if(d&&d.length) perfil=d[0];
      else{
        await fetch(C.sb+'/rest/v1/usuarios_perfil',{method:'POST',headers:Object.assign(H(),{'Prefer':'return=minimal'}),body:JSON.stringify({id:user.id,idioma:'cas'})});
        perfil={id:user.id,idioma:'cas',nombre:null,telefono:null,avisos_email:true};
      }
    }catch(e){ perfil={id:user.id,idioma:'cas'}; toast('Error cargando el perfil','err'); }
    pintarPerfil();
  }
  async function guardar(campos,cerrarId,ok){
    try{
      var res=await fetch(C.sb+'/rest/v1/usuarios_perfil?id=eq.'+encodeURIComponent(user.id),{method:'PATCH',headers:Object.assign(H(),{'Prefer':'return=minimal'}),body:JSON.stringify(campos)});
      if(!res.ok) throw new Error();
      perfil=Object.assign(perfil||{},campos); pintarPerfil();
      if(cerrarId) cerrar(cerrarId);
      toast(ok||'Guardado','ok');
    }catch(e){ toast('Error al guardar','err'); }
  }
  async function ultimaConexion(){
    var el=$('z-v-ultima'); if(!el) return;
    try{
      var res=await fetch(C.sb+'/auth/v1/user',{headers:{'apikey':C.key,'Authorization':'Bearer '+tok}});
      var d=await res.json(), t=d&&d.last_sign_in_at;
      if(!res.ok||!t){ el.textContent='—'; return; }
      var f=new Date(t), p=function(n){ return String(n).padStart(2,'0'); };
      el.textContent=p(f.getDate())+'/'+p(f.getMonth()+1)+'/'+f.getFullYear()+' '+p(f.getHours())+':'+p(f.getMinutes());
    }catch(e){ el.textContent='—'; }
  }

  // ── Construcción de la pantalla ──
  function fila(ico,txt,valId,valTxt,accion){
    return '<div class="z-row'+(accion?' click':'')+'"'+(accion?' data-z="'+accion+'"':'')+'><div class="z-rico">'+ico+'</div><div class="z-rlabel">'+txt+'</div>'
      +(valId||valTxt?'<div class="z-rval"'+(valId?' id="'+valId+'"':'')+'>'+esc(valTxt||'')+'</div>':'')+(accion?'<div class="z-rarrow">›</div>':'')+'</div>';
  }
  function modal(id,titulo,cuerpo,color){
    return '<div class="z-modal-bg" id="z-m-'+id+'"><div class="z-modal"><div class="z-modal-handle"></div>'
      +'<div class="z-modal-title"'+(color?' style="color:'+color+'"':'')+'>'+titulo+'</div>'+cuerpo
      +'<button class="z-btn-cancel" data-z="cerrar:'+id+'">Cancelar</button></div></div>';
  }
  function construir(){
    var em=(user&&user.email)||'';
    var h=$('z-hdr'); if(h) h.innerHTML='<div class="z-hdr"><button class="z-back" data-z="atras" aria-label="Volver">←</button><span class="z-hdr-title" id="z-titulo"></span></div>';
    var he=$('z-hero'); if(he) he.innerHTML='<div class="z-hero"><div class="z-avatar" id="z-avatar">?</div><div class="z-hero-name" id="z-hero-name">—</div><div class="z-hero-email">'+esc(em)+'</div><div class="z-hero-extra" id="z-hero-extra"></div></div>';
    var d=$('z-datos'); if(d) d.innerHTML='<div class="z-sec"><div class="z-sec-title">Datos personales</div><div class="z-card">'
      +fila('✏️','Nombre','z-v-nombre','—','abrir:nombre')+fila('📞','Teléfono','z-v-tel','—','abrir:tel')
      +fila('🌐','Idioma','z-v-idioma','CAS','abrir:idioma')+fila('📧','Email','',em,'')
      +fila('🔑','Contraseña','','Cambiar','abrir:pass')+fila('🔔','Avisos por correo','z-v-avisos','Sí','avisos')
      +'</div></div>';
    var s=$('z-sesion'); if(s) s.innerHTML='<div class="z-sec"><div class="z-sec-title">Sesión</div><div class="z-card">'
      +fila('🕓','Última conexión','z-v-ultima','—','')+fila('❓','Ayuda','','','ayuda')+fila('🚿','Cerrar sesión','','','salir')+'</div></div>';
    var r=$('z-riesgo'); if(r) r.innerHTML='<div class="z-sec" style="margin-top:8px"><div class="z-sec-title">Zona de riesgo</div><div class="z-danger">'
      +'<div class="z-danger-title">Eliminar perfil</div><div class="z-danger-txt">'+(C.textoBaja||'Al solicitar la eliminación, tu perfil se desactivará durante 30 días. Pasado ese plazo, todos tus datos se borrarán permanentemente.')+'</div>'
      +'<button class="z-btn-danger" data-z="abrir:baja">Solicitar eliminación de cuenta</button></div></div>';
    if(!$('z-modales')){
      var m=D.createElement('div'); m.id='z-modales';
      m.innerHTML=
        modal('nombre','Nombre','<div class="z-field"><label>Tu nombre</label><input type="text" id="z-i-nombre" maxlength="80" placeholder="Nombre y apellidos"></div><button class="z-btn" data-z="nombre-guardar">Guardar</button>')
       +modal('tel','Teléfono','<div class="z-field"><label>Teléfono de contacto</label><input type="tel" id="z-i-tel" maxlength="20" placeholder="600 000 000"></div><div class="z-err" id="z-tel-err"></div><button class="z-btn" data-z="tel-guardar">Guardar</button>')
       +modal('idioma','Idioma','<div id="z-langs" style="margin-bottom:8px"></div>')
       +modal('pass','Cambiar contraseña','<div class="z-field"><label>Nueva contraseña</label><input type="password" id="z-p1" placeholder="Mínimo 8 caracteres" autocomplete="new-password"></div><div class="z-field"><label>Repetir contraseña</label><input type="password" id="z-p2" placeholder="Repite la contraseña" autocomplete="new-password"></div><div class="z-err" id="z-pass-err"></div><button class="z-btn" data-z="pass-guardar">Cambiar contraseña</button>')
       +modal('baja','¿Eliminar tu cuenta?','<p style="font-size:13px;color:var(--text);line-height:1.6;margin-bottom:16px">Tu perfil se desactivará durante <strong>30 días</strong>. Pasado ese plazo, todos tus datos se eliminarán permanentemente.'+(C.avisoBaja?' '+C.avisoBaja:'')+'</p><div class="z-field"><label>Escribe tu email para confirmar</label><input type="email" id="z-baja-mail" placeholder="Tu email de acceso"></div><div class="z-err" id="z-baja-err"></div><button class="z-btn-danger" style="width:100%;padding:12px;font-size:13px" data-z="baja-confirmar">Sí, eliminar mi cuenta</button>','#dc2626');
      D.body.appendChild(m);
      m.addEventListener('click',function(e){ if(e.target.classList&&e.target.classList.contains('z-modal-bg')) e.target.classList.remove('open'); });
    }
    if(!$('z-toast')){ var t=D.createElement('div'); t.id='z-toast'; t.className='z-toast'; D.body.appendChild(t); }
  }
  function abrir(id){
    if(id==='nombre') $('z-i-nombre').value=(perfil&&perfil.nombre)||'';
    if(id==='tel'){ $('z-i-tel').value=(perfil&&perfil.telefono)||''; $('z-tel-err').textContent=''; }
    if(id==='idioma') pintarIdiomas();
    if(id==='pass'){ $('z-p1').value=''; $('z-p2').value=''; $('z-pass-err').textContent=''; }
    if(id==='baja'){ $('z-baja-mail').value=''; $('z-baja-err').textContent=''; }
    $('z-m-'+id).classList.add('open');
  }
  function cerrar(id){ var e=$('z-m-'+id); if(e) e.classList.remove('open'); }
  function pintarIdiomas(){
    var langs=[{id:'cas',label:'Castellano',ico:'🇪🇸'},{id:'eus',label:'Euskera',ico:'🏔️'}], cur=(perfil&&perfil.idioma)||'cas';
    $('z-langs').innerHTML=langs.map(function(l){
      return '<div class="z-lang-opt'+(cur===l.id?' sel':'')+'" data-z="idioma:'+l.id+'"><span class="z-lang-ico">'+l.ico+'</span><span class="z-lang-name">'+l.label+'</span><span>'+(cur===l.id?'✅':'')+'</span></div>';
    }).join('');
  }
  async function cambiarPass(){
    var p1=$('z-p1').value, p2=$('z-p2').value, err=$('z-pass-err'); err.textContent='';
    if(p1.length<8){ err.textContent='Mínimo 8 caracteres'; return; }
    if(p1!==p2){ err.textContent='Las contraseñas no coinciden'; return; }
    try{
      var res=await fetch(C.sb+'/auth/v1/user',{method:'PUT',headers:H(),body:JSON.stringify({password:p1})});
      if(!res.ok) throw new Error();
      cerrar('pass'); toast('Contraseña actualizada','ok');
    }catch(e){ err.textContent='Error al cambiar la contraseña'; }
  }
  async function confirmarBaja(){
    var mail=val('z-baja-mail'), err=$('z-baja-err'); err.textContent='';
    if(mail.toLowerCase()!==String(user.email||'').toLowerCase()){ err.textContent='El email no coincide'; return; }
    if(bajando) return; bajando=true;
    try{
      var res=await fetch(C.sb+'/rest/v1/rpc/solicitar_baja_cuenta',{method:'POST',headers:H(),body:'{}'});
      if(!res.ok){ var d=await res.json().catch(function(){ return {}; }); throw new Error(d.message||'Error al procesar la solicitud'); }
      cerrar('baja'); toast('Cuenta desactivada. Tienes 30 días para recuperarla.','ok');
      setTimeout(salir,3000);
    }catch(e){ err.textContent=e.message||'Error al procesar la solicitud'; bajando=false; }
  }

  // ── Pantallas internas (data-vista) ──
  function elsVista(){ return [].slice.call(D.querySelectorAll('[data-vista]')); }
  function hashVista(){ var v=location.hash.replace(/^#/,''); return elsVista().some(function(e){ return e.getAttribute('data-vista')===v; })?v:'principal'; }
  function vista(v,sinHistorial){
    var els=elsVista();
    if(!els.some(function(e){ return e.getAttribute('data-vista')===v; })) v='principal';
    var titulo=C.titulo;
    els.forEach(function(e){
      var es=(e.getAttribute('data-vista')===v);
      e.style.display=es?'':'none';
      if(es&&v!=='principal') titulo=e.getAttribute('data-titulo')||C.titulo;
    });
    var t=$('z-titulo'); if(t) t.textContent=titulo;
    if(!sinHistorial&&v!==actual){
      try{
        if(v==='principal'){ /* se vuelve con atrás() */ }
        else if(actual==='principal'){ history.pushState(null,'','#'+v); empujado=true; }
        else history.replaceState(null,'','#'+v);
      }catch(e){}
    }
    if(v==='principal') empujado=false;
    actual=v; W.scrollTo(0,0);
  }
  function atras(){
    if(actual!=='principal'){
      if(empujado){ history.back(); }
      else{ try{ history.replaceState(null,'',location.pathname+location.search); }catch(e){} vista('principal',true); }
    }else W.location.href='/';
  }
  W.addEventListener('popstate',function(){ var a=$('z-app'); if(a&&a.style.display!=='none') vista(hashVista(),true); });

  // ── Entrada ──
  async function entrar(){
    var a=$('z-acceso'); if(a) a.style.display='none';
    roles=await KBS.roles(C.sb,C.key,tok);
    if(!roles||!C.permiso(roles)){ acceso('sinperm'); return; }
    $('z-app').style.display='block';
    construir();
    await cargarPerfil();
    ultimaConexion();
    var v=hashVista(); vista(v,true);
    if(C.alEntrar) C.alEntrar({user:user,roles:roles,perfil:perfil});
  }
  function iniciar(cfg){
    C=cfg; if(!C.permiso) C.permiso=function(){ return true; };
    var a=$('z-acceso'); a.innerHTML=htmlAcceso(); a.className='z-acceso';
    D.addEventListener('keydown',function(e){ if(e.key==='Enter'&&e.target&&e.target.id==='z-pass') login(); });
    D.addEventListener('click',function(e){
      var t=e.target.closest?e.target.closest('[data-z]'):null; if(!t) return;
      var x=t.getAttribute('data-z'), p=x.split(':'), k=p[0], arg=p.slice(1).join(':');
      if(k==='vista') vista(arg);
      else if(k==='atras') atras();
      else if(k==='abrir') abrir(arg);
      else if(k==='cerrar') cerrar(arg);
      else if(k==='login') login();
      else if(k==='rec-mostrar'){ $('z-rec-email').value=val('z-email'); $('z-rec-msg').textContent=''; acceso('rec'); }
      else if(k==='login-mostrar') acceso('login');
      else if(k==='rec-enviar') recEnviar();
      else if(k==='np-guardar') npGuardar();
      else if(k==='salir') salir();
      else if(k==='ayuda') W.location.href=C.ayuda||'/pages/faq.html';
      else if(k==='ir') W.location.href=arg;
      else if(k==='nombre-guardar'){ var n=val('z-i-nombre'); guardar({nombre:n||null},'nombre','Nombre guardado'); }
      else if(k==='tel-guardar'){
        var tl=val('z-i-tel'); if(tl&&!/^[0-9+()\s.\-]{6,20}$/.test(tl)){ $('z-tel-err').textContent='Teléfono no válido'; return; }
        guardar({telefono:tl||null},'tel','Teléfono guardado');
      }
      else if(k==='idioma'){ try{ sessionStorage.setItem('kb_lang',arg); }catch(er){} guardar({idioma:arg},'idioma','Idioma guardado'); }
      else if(k==='avisos'){ guardar({avisos_email:!(perfil&&perfil.avisos_email!==false)},null,'Preferencia guardada'); }
      else if(k==='pass-guardar') cambiarPass();
      else if(k==='baja-confirmar') confirmarBaja();
    });
    var rec=hashRecuperacion();
    if(rec){ W._tokenRecuperacion=rec; acceso('new'); return; }
    tok=KBS.get(G('token')); var u=KBS.get(G('user'));
    if(tok&&u){
      try{ user=JSON.parse(u); }catch(e){ user=null; }
      if(user){
        if(jwtExp(tok)-Date.now()<60000) refrescar().then(function(ok){ if(ok) entrar(); else caducada(); });
        else entrar();
        return;
      }
    }
    acceso('login');
  }
  return {iniciar:iniciar,vista:vista,atras:atras,H:H,toast:toast,esc:esc,salir:salir,
    token:function(){ return tok; },user:function(){ return user; },perfil:function(){ return perfil; },roles:function(){ return roles; },
    fetchOriginal:function(){ return _fetch; },
    sinPermiso:function(){ acceso('sinperm'); },
    heroExtra:function(t){ var e=$('z-hero-extra'); if(e) e.textContent=t||''; }};
})();
