import React from 'react';
// SAHRA custom icon set — one uniform 1.6px line hand, drawn from Cairo dining culture
// (tea glass, mezze plate, lantern, shisha) alongside matching UI glyphs, so the whole
// app shares one voice instead of a generic third-party icon library.
const P={
  // Cairo dining object family
  lantern:"<path d='M12 2.5v1.6'/><path d='M9 4.6h6'/><path d='M9.6 6.6h4.8l-.5-2h-3.8z'/><path d='M9.4 6.6C8.7 9.6 8.7 13 9.4 16h5.2c.7-3 .7-6.4 0-9.4'/><path d='M11 7.4v8M13 7.4v8'/><path d='M9.9 16h4.2M11 18.2h2'/>",
  tea:"<path d='M9.6 5.6l.8 8.3c.1 1 3.1 1 3.2 0l.8-8.3z'/><path d='M9.6 5.6h4.8'/><path d='M7.6 17.4c1 .8 7.8 .8 8.8 0'/><path d='M11 15.6v1.8h2v-1.8'/><path d='M10.8 2.6c.7.7-.7 1.3 0 2M13 2.6c.7.7-.7 1.3 0 2'/>",
  mezze:"<circle cx='12' cy='12' r='8'/><circle cx='12' cy='12' r='2.3'/><circle cx='12' cy='6.8' r='1.4'/><circle cx='16.4' cy='14.6' r='1.4'/><circle cx='7.6' cy='14.6' r='1.4'/>",
  shisha:"<path d='M10.5 3.6h3v2h-3z'/><path d='M9 6h6'/><path d='M12 6v7'/><circle cx='12' cy='16.5' r='3.5'/><path d='M12 9c3.4 0 4.4 1.8 5.4 3.8'/>",
  // UI glyphs — same weight & caps
  search:"<circle cx='10.5' cy='10.5' r='6.4'/><path d='M20 20l-4.9-4.9'/>",
  x:"<path d='M6 6l12 12M18 6L6 18'/>",
  heart:"<path d='M12 20C12 20 4.5 15.4 4.5 9.9 4.5 7.4 6.4 5.7 8.6 5.7 10 5.7 11.2 6.5 12 7.7 12.8 6.5 14 5.7 15.4 5.7 17.6 5.7 19.5 7.4 19.5 9.9 19.5 15.4 12 20 12 20Z'/>",
  user:"<circle cx='12' cy='8' r='3.4'/><path d='M5.5 19.5c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6'/>",
  users:"<circle cx='9' cy='8.5' r='3'/><path d='M3.5 19c0-3 2.5-5 5.5-5s5.5 2 5.5 5'/><path d='M16 6.2a3 3 0 0 1 0 5.6M17.6 14.2c1.9 .6 2.9 2.3 2.9 4.8'/>",
  "chevron-down":"<path d='M6.5 9.5L12 15l5.5-5.5'/>",
  "chevron-right":"<path d='M9.5 6.5L15 12l-5.5 5.5'/>",
  "chevron-left":"<path d='M14.5 6.5L9 12l5.5 5.5'/>",
  "chevron-up":"<path d='M6.5 14.5L12 9l5.5 5.5'/>",
  "arrow-left":"<path d='M14 6l-6 6 6 6M8.2 12H19'/>",
  "arrow-right":"<path d='M10 6l6 6-6 6M15.8 12H5'/>",
  "map-pin":"<path d='M12 21c4-4.6 6-7.7 6-10.6A6 6 0 0 0 6 10.4C6 13.3 8 16.4 12 21Z'/><circle cx='12' cy='10.3' r='2.2'/>",
  clock:"<circle cx='12' cy='12' r='7.5'/><path d='M12 8v4.2l3 1.8'/>",
  calendar:"<rect x='4.5' y='5.5' width='15' height='14' rx='2.5'/><path d='M4.5 9.5h15M8.5 3.5v3M15.5 3.5v3'/>",
  "calendar-plus":"<rect x='4.5' y='5.5' width='15' height='14' rx='2.5'/><path d='M4.5 9.5h15M8.5 3.5v3M15.5 3.5v3M12 12.5v4M10 14.5h4'/>",
  "calendar-check":"<rect x='4.5' y='5.5' width='15' height='14' rx='2.5'/><path d='M4.5 9.5h15M8.5 3.5v3M15.5 3.5v3M9 14l2 2 4-3.6'/>",
  check:"<path d='M5 12.5l4.5 4.5L19 7'/>",
  "circle-check":"<circle cx='12' cy='12' r='8.5'/><path d='M8 12.3l2.7 2.7L16 9.5'/>",
  image:"<rect x='4.5' y='5.5' width='15' height='13' rx='2.5'/><circle cx='9' cy='10' r='1.6'/><path d='M6 17l4-4 3 3 2.5-2.5L19 15.5'/>",
  compass:"<circle cx='12' cy='12' r='8'/><path d='M15 9l-1.6 4.4L9 15l1.6-4.4z'/>",
  share:"<circle cx='7' cy='12' r='2'/><circle cx='17' cy='6.5' r='2'/><circle cx='17' cy='17.5' r='2'/><path d='M8.8 11l6.4-3.5M8.8 13l6.4 3.5'/>",
  phone:"<path d='M7 4.5c1 0 1.6.4 2 1.5l.9 2.4c.3.9 0 1.4-.6 1.9l-1 .8c1 2 2.3 3.3 4.3 4.3l.8-1c.5-.6 1-.9 1.9-.6l2.4.9c1.1.4 1.5 1 1.5 2 0 2.4-2 3.3-4 2.8C10 20.5 3.5 14 3.6 8.6 3.6 6.6 4.3 4.5 7 4.5z'/>",
  plus:"<path d='M12 5.5v13M5.5 12h13'/>",
  bell:"<path d='M6.5 17c1-1 1.5-2.3 1.5-4v-2a4 4 0 0 1 8 0v2c0 1.7.5 3 1.5 4z'/><path d='M10 17v.4a2 2 0 0 0 4 0V17'/>",
  tag:"<path d='M4.5 10.5v-5a1 1 0 0 1 1-1h5l9 9a1.4 1.4 0 0 1 0 2l-5 5a1.4 1.4 0 0 1-2 0z'/><circle cx='8.5' cy='8.5' r='1.4'/>",
  ticket:"<path d='M4.5 6.5h15v3.2a2.3 2.3 0 0 0 0 4.6v3.2h-15v-3.2a2.3 2.3 0 0 0 0-4.6z'/><path d='M14.5 6.5v11' stroke-dasharray='2 2.4'/>",
  "credit-card":"<rect x='3.5' y='6' width='17' height='12' rx='2.5'/><path d='M3.5 10h17'/>",
  globe:"<circle cx='12' cy='12' r='8'/><path d='M4 12h16M12 4c2.6 2.2 2.6 13.8 0 16M12 4c-2.6 2.2-2.6 13.8 0 16'/>",
  "circle-help":"<circle cx='12' cy='12' r='8.5'/><path d='M9.7 9.6a2.3 2.3 0 0 1 4.4.8c0 1.6-2.1 1.8-2.1 3.1'/><path d='M12 16.6h.01'/>",
  "layout-grid":"<rect x='4.5' y='4.5' width='6' height='6' rx='1.5'/><rect x='13.5' y='4.5' width='6' height='6' rx='1.5'/><rect x='4.5' y='13.5' width='6' height='6' rx='1.5'/><rect x='13.5' y='13.5' width='6' height='6' rx='1.5'/>",
  "moon-star":"<path d='M18.5 14.2A7 7 0 1 1 9.8 5.5a5.5 5.5 0 0 0 8.7 8.7z'/><path d='M17.3 3.8l.6 1.4 1.4.6-1.4.6-.6 1.4-.6-1.4-1.4-.6 1.4-.6z'/>",
  star:"<path d='M12 4.6l2.2 4.6 5 .7-3.6 3.5.9 5-4.5-2.4-4.5 2.4.9-5L4.8 9.9l5-.7z'/>",
  spark:"<path d='M12 4l1.4 4.6L18 10l-4.6 1.4L12 16l-1.4-4.6L6 10l4.6-1.4z'/>",
  "calendar-check2":"",
};
export function Icon({name,size=20,style}){
  const inner=P[name];
  if(inner) return <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="currentColor" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" style={{flexShrink:0,display:'inline-block',...style}} dangerouslySetInnerHTML={{__html:inner}}/>;
  const m='url(https://unpkg.com/lucide-static@0.462.0/icons/'+name+'.svg)';
  return <span aria-hidden="true" style={{width:size,height:size,display:'inline-block',flexShrink:0,background:'currentColor',WebkitMaskImage:m,maskImage:m,WebkitMaskSize:'contain',maskSize:'contain',WebkitMaskRepeat:'no-repeat',maskRepeat:'no-repeat',WebkitMaskPosition:'center',maskPosition:'center',...style}}></span>;
}
