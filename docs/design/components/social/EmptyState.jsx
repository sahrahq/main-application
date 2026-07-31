import React from 'react';
import {Button} from '../core/Button';
import {Icon} from '../core/Icon';
import {Mashrabiya} from '../brand/Mashrabiya';
export function EmptyState({icon='moon-star',title,message,actionLabel,onAction,style}){
  return <div style={{position:'relative',textAlign:'center',padding:'40px 24px',display:'flex',flexDirection:'column',alignItems:'center',gap:8,fontFamily:'var(--font-latin)',...style}}>
    <Mashrabiya color="var(--text-body)" opacity={0.045} tile={46} fade/>
    <span style={{width:56,height:56,borderRadius:'50%',background:'var(--surface-sunken)',color:'var(--terracotta)',display:'flex',alignItems:'center',justifyContent:'center'}}><Icon name={icon} size={24}/></span>
    <div style={{fontFamily:'var(--font-display)',fontSize:19,fontWeight:600,letterSpacing:'-.01em',marginTop:8,color:'var(--text-body)'}}>{title}</div>
    {message&&<div style={{fontSize:13,color:'var(--text-soft)',maxWidth:300,lineHeight:1.5}}>{message}</div>}
    {actionLabel&&<Button size="sm" style={{marginTop:8}} onClick={onAction}>{actionLabel}</Button>}
  </div>;
}