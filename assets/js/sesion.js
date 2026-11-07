// Kirolorik · sesion.js · v1.0 · 2026-11-07
// Guarda la sesión (token de acceso, refresh token y usuario) donde corresponda:
//  · con «Mantener sesión iniciada» marcada: localStorage (sigue al cerrar el navegador, como hace la librería de Supabase);
//  · sin marcar: sessionStorage (se borra al cerrar la pestaña, como antes).
// Dos grupos de claves independientes: 'kb' (kb_token, kb_user, kb_refresh) y 'kb_admin' (kb_admin_token, kb_admin_user, kb_admin_refresh).
// Si ya había una sesión en sessionStorage (de antes de esta versión), se sigue leyendo y se renueva donde está.
var KBS=(function(){
  var W=window;
  var NOMBRES=['token','user','refresh'];
  function grupo(k){ return String(k).indexOf('kb_admin_')===0?'kb_admin':'kb'; }
  function persistente(g){ try{ return W.localStorage.getItem(g+'_persist')==='1'; }catch(e){ return false; } }
  function get(k){
    try{ var v=W.localStorage.getItem(k); if(v!=null) return v; }catch(e){}
    try{ return W.sessionStorage.getItem(k); }catch(e){ return null; }
  }
  function set(k,v){
    var per=persistente(grupo(k));
    try{ W[per?'sessionStorage':'localStorage'].removeItem(k); }catch(e){}
    try{ W[per?'localStorage':'sessionStorage'].setItem(k,v); }
    catch(e){ try{ W.sessionStorage.setItem(k,v); }catch(e2){} }
  }
  function remove(k){
    try{ W.localStorage.removeItem(k); }catch(e){}
    try{ W.sessionStorage.removeItem(k); }catch(e){}
  }
  function clear(g){ NOMBRES.forEach(function(n){ remove(g+'_'+n); }); }
  // Elige dónde se guarda a partir de ahora y mueve lo que hubiera guardado
  function setPersist(on,g){
    g=g||'kb';
    try{ if(on) W.localStorage.setItem(g+'_persist','1'); else W.localStorage.removeItem(g+'_persist'); }catch(e){}
    NOMBRES.forEach(function(n){ var k=g+'_'+n, v=get(k); if(v!=null) set(k,v); });
  }
  function expMs(t){
    try{ return JSON.parse(atob(String(t).split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).exp*1000; }catch(e){ return 0; }
  }
  // Evita que dos pestañas renueven a la vez con el mismo refresh token (el segundo uso invalidaría la sesión)
  function lock(nombre,fn){
    try{ if(W.navigator&&W.navigator.locks&&W.navigator.locks.request) return W.navigator.locks.request(nombre,fn); }catch(e){}
    return Promise.resolve().then(fn);
  }
  // Cierra la sesión: borra lo guardado y revoca en el servidor solo esta sesión (scope=local), sin cerrar la de otros dispositivos
  function cerrar(SB,KEY,g,hecho){
    g=g||'kb';
    var rt=get(g+'_refresh'), tk=get(g+'_token');
    clear(g);
    function salir(t){
      return W.fetch(SB+'/auth/v1/logout?scope=local',{method:'POST',keepalive:true,headers:{'apikey':KEY,'Authorization':'Bearer '+t}});
    }
    var p=Promise.resolve();
    if(tk&&expMs(tk)>Date.now()+5000) p=salir(tk);
    else if(rt) p=W.fetch(SB+'/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{'apikey':KEY,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:rt})})
      .then(function(r){ return r.ok?r.json():null; }).then(function(d){ return d&&d.access_token?salir(d.access_token):null; });
    var tope=new Promise(function(r){ setTimeout(r,2000); });
    return Promise.race([p.catch(function(){}),tope]).then(function(){ if(hecho) hecho(); });
  }
  return {get:get,set:set,remove:remove,clear:clear,setPersist:setPersist,persistente:persistente,lock:lock,cerrar:cerrar,expMs:expMs};
})();
