import React from 'react';
// Mashrabiya — traditional Cairo carved-wood screen, abstracted to an eight-point-star lattice.
// SAHRA's signature texture: card dividers, empty/loading states, occasion backdrops. Distinctly
// Cairene, not a generic 'Arabic pattern'. Tiles seamlessly (rotated square corners meet neighbours).
export function mashrabiyaUrl(color='rgba(221,95,53,0.5)',tile=44){
  const svg="<svg xmlns='http://www.w3.org/2000/svg' width='"+tile+"' height='"+tile+"' viewBox='0 0 44 44'><g fill='none' stroke='"+color+"' stroke-width='1'><path d='M22 2 L42 22 L22 42 L2 22 Z'/><path d='M8 8 H36 V36 H8 Z'/></g></svg>";
  return "url(\"data:image/svg+xml,"+encodeURIComponent(svg)+"\")";
}
export function Mashrabiya({color='rgba(221,95,53,0.5)',opacity=1,tile=44,fade,style,children}){
  const mask=fade?{WebkitMaskImage:'radial-gradient(120% 100% at 50% 0%,#000,transparent 78%)',maskImage:'radial-gradient(120% 100% at 50% 0%,#000,transparent 78%)'}:{};
  return <div aria-hidden="true" style={{position:'absolute',inset:0,backgroundImage:mashrabiyaUrl(color,tile),backgroundSize:tile+'px '+tile+'px',opacity,pointerEvents:'none',...mask,...style}}>{children}</div>;
}
