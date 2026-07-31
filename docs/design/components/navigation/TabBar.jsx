import React from 'react';
import {Icon} from '../core/Icon';
const defaults=[{id:'discover',label:'Discover',icon:'layout-grid'},{id:'search',label:'Search',icon:'search'},{id:'account',label:'Account',icon:'user'}];
export function TabBar({items=defaults,active,onChange,style}){
  const [cur,setCur]=React.useState(active||items[0].id);
  const sel=active!==undefined?active:cur;
  return <nav style={{display:'flex',background:'var(--surface-page)',borderTop:'1px solid var(--line)',padding:'10px 8px 14px',boxSizing:'border-box',...style}}>
    {items.map(it=>{const on=sel===it.id;
      return <button key={it.id} onClick={()=>{setCur(it.id);onChange&&onChange(it.id)}} style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',gap:4,background:'none',border:'none',cursor:'pointer',color:on?'var(--terracotta)':'var(--text-faint)',fontFamily:'var(--font-latin)',padding:0}}>
        <Icon name={it.icon} size={20}/>
        <span style={{fontSize:10,fontWeight:600}}>{it.label}</span>
        <span style={{width:4,height:4,borderRadius:2,background:on?'var(--terracotta)':'transparent'}}></span>
      </button>;})}
  </nav>;
}