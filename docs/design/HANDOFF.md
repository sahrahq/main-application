# SAHRA — Developer Handoff

Generated from source. Tokens: `docs/tokens.json` (root = light theme; `themeNight` overrides apply under `.theme-night`).

## Fonts
- Display: Newsreader (Google Fonts)
- Latin UI/body: Poppins (self-hosted, `assets/fonts/`)
- Arabic display: Reem Kufi · Arabic UI/body: IBM Plex Sans Arabic (Google Fonts)

## Theming
- Light is default (`:root`). Dark = add `.theme-night` class on any subtree.
- RTL: set `dir="rtl"` + `lang="ar"`; fonts switch automatically.
- Accessibility: global `:focus-visible` outline ships in tokens/typography.css. Gold `#E0A96D` is icon/accent-only on light surfaces — use `--gold-dark` for text.

## Logo
- `assets/logo.png` — cream mark, dark/terracotta surfaces.
- `assets/logo-terracotta.png` — terracotta mark, light surfaces.

## Component APIs

### components/core

**Badge**
```ts
export interface BadgeProps{variant?:'featured'|'gold'|'success'|'warning'|'error'|'neutral';children?:React.ReactNode;style?:React.CSSProperties}
export function Badge(props:BadgeProps):JSX.Element;
```

**Button**
```ts
export interface ButtonProps{variant?:'primary'|'secondary'|'ghost'|'gold';size?:'sm'|'md'|'lg';pill?:boolean;disabled?:boolean;icon?:React.ReactNode;children?:React.ReactNode;onClick?:()=>void;style?:React.CSSProperties}
export function Button(props:ButtonProps):JSX.Element;
```

**Chip**
```ts
export interface ChipProps{active?:boolean;icon?:React.ReactNode;children?:React.ReactNode;onClick?:()=>void;style?:React.CSSProperties}
export function Chip(props:ChipProps):JSX.Element;
```

**Icon**
```ts
/** SAHRA custom icon — one uniform 1.6px line hand drawn from Cairo dining culture, not a generic library. Unknown names fall back to Lucide. */
export interface IconProps{name:string;size?:number;style?:React.CSSProperties}
export function Icon(props:IconProps):JSX.Element;
```

**Input**
```ts
export interface InputProps{label?:string;help?:string;error?:string;variant?:'box'|'line';placeholder?:string;type?:string;style?:React.CSSProperties;inputStyle?:React.CSSProperties}
export function Input(props:InputProps):JSX.Element;
```

**Skeleton**
```ts
export interface SkeletonProps{width?:number|string;height?:number|string;radius?:number|string;lattice?:boolean;style?:React.CSSProperties}
export function Skeleton(props:SkeletonProps):JSX.Element;
export function SkeletonCard(props:{style?:React.CSSProperties}):JSX.Element;
```

### components/venue

**BookingWidget**
```ts
export interface BookingWidgetProps{venue?:string;times?:string[];defaultTime?:string;defaultParty?:number;onBook?:(r:{party:number;time:string})=>void;width?:number|string;style?:React.CSSProperties}
export function BookingWidget(props:BookingWidgetProps):JSX.Element;
```

**RatingStars**
```ts
export interface RatingStarsProps{rating?:number|string;reviews?:number|string;size?:number;showValue?:boolean;style?:React.CSSProperties}
export function RatingStars(props:RatingStarsProps):JSX.Element;
```

**RestaurantCard**
```ts
export interface RestaurantCardProps{name:string;rating:number|string;reviews:number|string;cuisine:string;price?:string;neighbourhood?:string;image?:string;tone?:'terrace'|'dusk'|'garden'|'gold'|'night';featured?:boolean;availability?:string;saved?:boolean;onSave?:()=>void;onClick?:()=>void;width?:number|string;imageHeight?:number;style?:React.CSSProperties}
export function RestaurantCard(props:RestaurantCardProps):JSX.Element;
```

### components/social

**Avatar**
```ts
export interface AvatarProps{name?:string;src?:string;size?:number;style?:React.CSSProperties}
export function Avatar(props:AvatarProps):JSX.Element;
```

**AvatarStack**
```ts
export interface AvatarStackProps{people:{name?:string;src?:string}[];max?:number;size?:number;label?:string;style?:React.CSSProperties}
export function AvatarStack(props:AvatarStackProps):JSX.Element;
```

**EmptyState**
```ts
export interface EmptyStateProps{icon?:string;title:string;message?:string;actionLabel?:string;onAction?:()=>void;style?:React.CSSProperties}
export function EmptyState(props:EmptyStateProps):JSX.Element;
```

### components/navigation

**SearchBar**
```ts
export interface SearchBarProps{placeholder?:string;location?:string;onChange?:(e:any)=>void;style?:React.CSSProperties;inputStyle?:React.CSSProperties}
export function SearchBar(props:SearchBarProps):JSX.Element;
```

**TabBar**
```ts
export interface TabBarProps{items?:{id:string;label:string;icon:string}[];active?:string;onChange?:(id:string)=>void;style?:React.CSSProperties}
export function TabBar(props:TabBarProps):JSX.Element;
```

### components/brand

**DiningTrail**
```ts
export interface DiningTrailProps{visits:{name:string;date:string;note?:string}[];style?:React.CSSProperties}
export function DiningTrail(props:DiningTrailProps):JSX.Element;
```

**Mashrabiya**
```ts
export interface MashrabiyaProps{color?:string;opacity?:number;tile?:number;fade?:boolean;style?:React.CSSProperties;children?:React.ReactNode}
export function Mashrabiya(props:MashrabiyaProps):JSX.Element;
export function mashrabiyaUrl(color?:string,tile?:number):string;
```

### ui_kits
- `ui_kits/app/` — consumer app screens (SplashScreen, Onboarding, SignInScreen, DiscoverScreen, SearchScreen, VenueDetailScreen, BookingFlowScreen, ConfirmationScreen, MyBookingsScreen, SavedScreen, ProfileScreen, OccasionScreen). All accept `lang` ('en'|'ar'); theme via parent `.theme-night`.

### Feature notes (2026-07 parity pass)
- **Notify-me**: sold-out booking slots render a bell chip (BookingFlow); watched slots surface as a "Watching" card in My bookings.
- **Menu + pricing**: VenueDetail has a menu section with EGP prices.
- **Offers**: gold offer strip (e.g. "20% off before 7:30 PM") on VenueDetail + Discover.
- **Events**: ticketed-experience row on Discover (oud nights etc.).
- **Share + review**: share action on confirmed bookings; post-visit review stars prompt on Discover.
- **Loyalty**: Profile points strip — gold spark icon, "240 points · 60 to your free dessert", 4px gold progress bar in a `--surface-card` capsule (radius 12, 1px `--line`).
- **Search map**: real OpenStreetMap tiles (Zamalek), sepia tint on light / night treatment on dark, terracotta pins.
- `ui_kits/operator/` — OperatorDashboard (`dark` prop).

### Motion notes (for native implementation)
- Splash: mark settle .7s cubic-bezier(.2,.7,.2,1), wordmark tracking-in .8s, gold hairline draw .5s, fade-out .38s. Total ~2.4s.
- Confirmation: staggered rise (.5s/.55s, 0/.12s/.22s delays), spark pop cubic-bezier(.34,1.5,.5,1).
- Save heart: pop .4s cubic-bezier(.34,1.6,.5,1) + gold ring ripple .5s.
- Skeleton: gold shimmer sweep 1.6s infinite over mashrabiya lattice at 5% opacity.
- Pull-to-refresh: lantern glyph fills with gold as you pull, glows at threshold (Discover).

## Handoff to development
Design rules for implementers live in `docs/DESIGN-RULES.md` — place it in the app repo and link it from the repo's root CLAUDE.md.
