import React from 'react';
import {Badge} from '../core/Badge';
import {Icon} from '../core/Icon';
import {RatingStars} from './RatingStars';
import {Mashrabiya} from '../brand/Mashrabiya';
export function RestaurantCard({name,rating,reviews,cuisine,price='$$$',neighbourhood,image,tone='terrace',featured,availability,saved,onSave,onClick,width=280,imageHeight=160,style}){
  const bg=image?('#2E2219 url('+image+') center/cover'):'linear-gradient(150deg,#4A392C,#2C2018)';
  return <div onClick={onClick} style={{width,background:'var(--surface-card)',border:'1px solid var(--line)',borderRadius:'var(--radius-lg)',overflow:'hidden',cursor:onClick?'pointer':'default',fontFamily:'var(--font-latin)',boxShadow:'var(--shadow-1)',boxSizing:'border-box',...style}}>
    <div style={{position:'relative',height:imageHeight,background:bg}}>
      {!image&&<Mashrabiya color="rgba(253,251,247,0.09)" tile={38}/>}
      {!image&&<div style={{position:'absolute',inset:0,display:'flex',alignItems:'center',justifyContent:'center',color:'rgba(253,251,247,.16)'}}><Icon name="image" size={30}/></div>}
      {featured&&<Badge variant="featured" style={{position:'absolute',top:12,left:12}}>Featured</Badge>}
      <button onClick={e=>{e.stopPropagation();onSave&&onSave()}} style={{position:'absolute',top:10,right:10,width:34,height:34,borderRadius:'50%',border:'none',background:'rgba(20,12,8,.42)',backdropFilter:'blur(4px)',cursor:'pointer',color:saved?'var(--gold)':'#FDFBF7',display:'flex',alignItems:'center',justifyContent:'center',overflow:'visible'}}>
        <style>{`@keyframes sahraHeartPop{0%{transform:scale(.4)}55%{transform:scale(1.35)}100%{transform:scale(1)}}@keyframes sahraHeartRing{0%{transform:scale(.4);opacity:.8}100%{transform:scale(1.9);opacity:0}}`}</style>
        {saved&&<span aria-hidden="true" style={{position:'absolute',inset:0,borderRadius:'50%',border:'1.5px solid var(--gold)',animation:'sahraHeartRing .5s ease-out both',pointerEvents:'none'}}></span>}
        <span key={saved?'s':'u'} style={{display:'flex',animation:saved?'sahraHeartPop .4s cubic-bezier(.34,1.6,.5,1) both':'none'}}><Icon name="heart" size={17} style={saved?{color:'var(--gold)'}:{}}/></span>
      </button>
      <div style={{position:'absolute',left:0,right:0,bottom:0,height:60,background:'linear-gradient(transparent,rgba(20,12,8,.55))'}}></div>
    </div>
    <div style={{padding:'13px 16px 16px'}}>
      <div style={{fontFamily:'var(--font-display)',fontSize:19,fontWeight:600,color:'var(--text-body)',letterSpacing:'-.01em'}}>{name}</div>
      <div style={{display:'flex',alignItems:'center',gap:8,marginTop:5,fontSize:12,color:'var(--text-faint)'}}>
        <RatingStars rating={rating} reviews={reviews} size={12}/>
        <span>· {cuisine} · {price}</span>
      </div>
      {neighbourhood&&<div style={{fontSize:12,color:'var(--text-faint)',marginTop:3,display:'flex',alignItems:'center',gap:4}}><Icon name="map-pin" size={12}/>{neighbourhood}</div>}
      {availability&&<div style={{marginTop:12,paddingTop:12,borderTop:'1px solid var(--line)',fontSize:12,fontWeight:600,color:'var(--text-soft)',display:'flex',alignItems:'center',gap:6}}><Icon name="clock" size={14} style={{color:'var(--terracotta)'}}/>{availability}</div>}
    </div>
  </div>;
}
