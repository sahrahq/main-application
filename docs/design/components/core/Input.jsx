import React from 'react';
export function Input({label,help,error,variant='box',style,inputStyle,...rest}){
  const [focus,setFocus]=React.useState(false);
  const bc=error?'var(--error)':focus?'var(--terracotta)':'var(--line)';
  const box={width:'100%',fontFamily:'var(--font-latin)',fontSize:14,padding:'12px 14px',border:'1.5px solid '+bc,borderRadius:'var(--radius-md)',background:'var(--surface-card)',color:'var(--text-body)',outline:'none',boxShadow:focus&&!error?'0 0 0 3px var(--terracotta-tint)':'none',boxSizing:'border-box'};
  const line={width:'100%',fontFamily:'var(--font-latin)',fontSize:14,padding:'8px 0',border:'none',borderBottom:'1.5px solid '+bc,background:'transparent',color:'var(--text-body)',outline:'none',boxSizing:'border-box'};
  const isLine=variant==='line';
  return <label style={{display:'block',fontFamily:'var(--font-latin)',...style}}>
    {label&&<span style={{display:'block',fontSize:isLine?10:13,fontWeight:600,letterSpacing:isLine?'var(--tracking-overline)':'normal',textTransform:isLine?'uppercase':'none',color:isLine?'var(--text-faint)':'var(--text-body)',marginBottom:6}}>{label}</span>}
    <input {...rest} onFocus={e=>{setFocus(true);rest.onFocus&&rest.onFocus(e)}} onBlur={e=>{setFocus(false);rest.onBlur&&rest.onBlur(e)}} style={{...(isLine?line:box),...inputStyle}}/>
    {(error||help)&&<span style={{display:'block',fontSize:12,marginTop:6,color:error?'var(--error)':'var(--text-faint)'}}>{error||help}</span>}
  </label>;
}
