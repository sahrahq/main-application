import React from 'react';
import {Icon} from '../../components/core/Icon';
import {mashrabiyaUrl} from '../../components/brand/Mashrabiya';
let leafletP=null;
function loadLeaflet(){
  if(window.L)return Promise.resolve(window.L);
  if(leafletP)return leafletP;
  leafletP=new Promise((res,rej)=>{
    const css=document.createElement('link');
    css.rel='stylesheet';css.href='https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';css.integrity='sha384-sHL9NAb7lN7rfvG5lfHpm643Xkcjzp4jFvuavGOndn6pjVqS6ny56CAt3nsEVT4H';css.crossOrigin='anonymous';
    document.head.appendChild(css);
    const s=document.createElement('script');
    s.src='https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';s.integrity='sha384-cxOPjt7s7Iz04uaHJceBmS+qpjv2JkIHNVcuOrM+YHwZOmJGBXI00mdUXEq65HTH';s.crossOrigin='anonymous';
    s.onload=()=>res(window.L);s.onerror=rej;
    document.head.appendChild(s);
  });
  return leafletP;
}
const DEFAULT_PINS=[
  {name:'Layali Lounge',pos:[30.0622,31.2185],time:'9:00'},
  {name:'Sequoia',pos:[30.0742,31.2249],time:'8:30'},
  {name:'Kazoku',pos:[30.0585,31.2228],time:'10:00'}
];
// Real street map of Zamalek, Cairo (Leaflet + OpenStreetMap) with the SAHRA warm-paper tile
// treatment, terracotta availability pins, and a gold "you" beacon. Falls back to a lattice
// placeholder until tiles arrive.
export function MapCard({height=190,city='CAIRO',pins=DEFAULT_PINS,center=[30.0645,31.2215],zoom=14,onPin,interactive=true}){
  const ref=React.useRef(null);
  const mapRef=React.useRef(null);
  const [ready,setReady]=React.useState(false);
  React.useEffect(()=>{
    let dead=false;
    loadLeaflet().then(L=>{
      if(dead||!ref.current||mapRef.current)return;
      const map=L.map(ref.current,{zoomControl:false,scrollWheelZoom:false,dragging:interactive,attributionControl:true});
      map.attributionControl.setPrefix(false);
      map.setView(center,zoom);
      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{attribution:'© OpenStreetMap contributors'}).addTo(map);
      L.marker(center,{icon:L.divIcon({className:'',html:'<span class="sahra-you"></span>',iconSize:[14,14],iconAnchor:[7,7]}),interactive:false}).addTo(map);
      pins.forEach(p=>{
        const m=L.marker(p.pos,{icon:L.divIcon({className:'',html:'<span class="sahra-pin">'+p.time+'</span>',iconSize:[0,0],iconAnchor:[0,26]})}).addTo(map);
        if(onPin)m.on('click',()=>onPin(p));
      });
      mapRef.current=map;
      map.whenReady(()=>{if(!dead)setTimeout(()=>setReady(true),150)});
    }).catch(()=>{});
    return()=>{dead=true;if(mapRef.current){mapRef.current.remove();mapRef.current=null}};
  },[]);
  React.useEffect(()=>{if(mapRef.current)setTimeout(()=>mapRef.current.invalidateSize(),320)},[height]);
  return <div className="sahra-map" style={{position:'relative',height,borderRadius:'var(--radius-lg)',overflow:'hidden',border:'1px solid var(--line)',background:'var(--surface-card)',transition:'height .3s cubic-bezier(.2,.7,.3,1)'}}>
    <style>{`
      .sahra-map .leaflet-tile{filter:sepia(.32) saturate(.72) hue-rotate(-10deg) brightness(1.04) contrast(.92)}
      .theme-night .sahra-map .leaflet-tile{filter:invert(1) hue-rotate(185deg) brightness(.82) saturate(.55) sepia(.22)}
      .sahra-map .leaflet-container{background:var(--surface-sunken);font-family:var(--font-latin)}
      .sahra-map .leaflet-control-attribution{background:rgba(253,251,247,.7);font-size:8px;color:#8A7563}
      .theme-night .sahra-map .leaflet-control-attribution{background:rgba(26,18,12,.7);color:#A38D7C}
      .sahra-pin{display:inline-block;background:var(--terracotta);color:#fff;font-size:11px;font-weight:700;font-family:var(--font-latin);padding:4px 9px;border-radius:999px;white-space:nowrap;box-shadow:0 3px 10px rgba(0,0,0,.3);position:relative;transform:translateX(-50%)}
      .sahra-pin::after{content:'';position:absolute;left:50%;bottom:-4px;width:8px;height:8px;background:var(--terracotta);transform:translateX(-50%) rotate(45deg);border-radius:1px}
      .sahra-you{display:block;width:14px;height:14px;border-radius:50%;background:var(--gold);border:2.5px solid #fff;box-shadow:0 0 0 0 rgba(224,169,109,.55);animation:sahraYou 2.2s ease-out infinite}
      @keyframes sahraYou{0%{box-shadow:0 0 0 0 rgba(224,169,109,.55)}100%{box-shadow:0 0 0 16px rgba(224,169,109,0)}}
    `}</style>
    <div ref={ref} style={{position:'absolute',inset:0,zIndex:0}}></div>
    {!ready&&<div style={{position:'absolute',inset:0,background:'var(--surface-sunken)',display:'flex',alignItems:'center',justifyContent:'center',zIndex:2}}>
      <div style={{position:'absolute',inset:0,backgroundImage:mashrabiyaUrl('currentColor',40),color:'var(--text-body)',opacity:.05}}></div>
      <Icon name="map-pin" size={22} style={{color:'var(--text-faint)'}}/>
    </div>}
    <span style={{position:'absolute',insetInlineStart:12,top:10,fontSize:10,fontWeight:700,letterSpacing:'.2em',color:'var(--text-soft)',background:'var(--surface-card)',padding:'4px 10px',borderRadius:999,border:'1px solid var(--line)',zIndex:3}}>{city}</span>
  </div>;
}
