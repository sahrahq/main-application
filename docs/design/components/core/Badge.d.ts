export interface BadgeProps{variant?:'featured'|'gold'|'success'|'warning'|'error'|'neutral';children?:React.ReactNode;style?:React.CSSProperties}
export function Badge(props:BadgeProps):JSX.Element;