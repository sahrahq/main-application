import React from 'react';
import {Icon} from '../core/Icon';
export function SearchBar({placeholder='Search',location='Cairo',onChange,style,inputStyle}){
  return <div style={{display:'flex',alignItems:'center',gap:10,background:'var(--surface-sunken)',border:'1px solid var(--line)',borderRadius:'var(--radius-pill)',padding:'10px 16px',fontFamily:'var(--font-latin)',boxSizing:'border-box',...style}}>
    <span style={{color:'var(--text-faint)',display:'flex'}}><Icon name="search" size={16}/></span>
    <input placeholder={placeholder} onChange={onChange} style={{flex:1,minWidth:0,background:'transparent',border:'none',outline:'none',color:'var(--text-body)',fontSize:14,fontFamily:'var(--font-latin)',...inputStyle}}/>
    {location&&<span style={{fontSize:13,fontWeight:600,color:'var(--gold)'}}>{location}</span>}
  </div>;
}