import React from 'react';
import {Icon} from '../../components/core/Icon';
import {Mashrabiya} from '../../components/brand/Mashrabiya';
export function Photo({src,image,height,radius=0,label,children,gradientOverlay,cue=true,style}){
  const url=src||image;
  return <div style={{position:'relative',width:'100%',height,borderRadius:radius,overflow:'hidden',background:url?('#2E2219 url('+url+') center/cover'):'linear-gradient(150deg,#4A392C,#2C2018)',...style}}>
    {!url&&<Mashrabiya color="rgba(253,251,247,0.09)" tile={40}/>}
    {!url&&<div style={{position:'absolute',inset:0,background:'radial-gradient(120% 100% at 30% 0%,rgba(255,255,255,.05),transparent 60%)'}}></div>}
    {!url&&cue&&<div style={{position:'absolute',inset:0,display:'flex',alignItems:'center',justifyContent:'center',color:'rgba(253,251,247,.18)'}}><Icon name="image" size={Math.max(22,Math.min(40,(parseInt(height)||120)*0.28))}/></div>}
    {gradientOverlay&&<div style={{position:'absolute',left:0,right:0,bottom:0,height:'62%',background:'linear-gradient(transparent,rgba(20,12,8,.82))'}}></div>}
    {label&&<span style={{position:'absolute',left:12,top:12,fontSize:10,fontWeight:700,letterSpacing:'.16em',textTransform:'uppercase',color:'rgba(253,251,247,.8)'}}>{label}</span>}
    {children}
  </div>;
}
