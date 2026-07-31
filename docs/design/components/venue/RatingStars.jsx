import React from 'react';
export function RatingStars({rating=0,reviews,size=13,showValue=true,style}){
  return <span style={{display:'inline-flex',alignItems:'center',gap:5,fontFamily:'var(--font-latin)',fontSize:size,...style}}>
    <span style={{color:'var(--terracotta)',fontWeight:700,letterSpacing:'.5px'}}>★</span>
    {showValue&&<b style={{color:'var(--terracotta)',fontWeight:700}}>{rating}</b>}
    {reviews!=null&&<span style={{color:'var(--text-faint)'}}>({reviews})</span>}
  </span>;
}