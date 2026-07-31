/* @ds-bundle: {"format":4,"namespace":"SAHRADesignSystem_5fbe17","components":[{"name":"DiningTrail","sourcePath":"components/brand/DiningTrail.jsx"},{"name":"Mashrabiya","sourcePath":"components/brand/Mashrabiya.jsx"},{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Chip","sourcePath":"components/core/Chip.jsx"},{"name":"Icon","sourcePath":"components/core/Icon.jsx"},{"name":"Input","sourcePath":"components/core/Input.jsx"},{"name":"Skeleton","sourcePath":"components/core/Skeleton.jsx"},{"name":"SkeletonCard","sourcePath":"components/core/Skeleton.jsx"},{"name":"SearchBar","sourcePath":"components/navigation/SearchBar.jsx"},{"name":"TabBar","sourcePath":"components/navigation/TabBar.jsx"},{"name":"Avatar","sourcePath":"components/social/Avatar.jsx"},{"name":"AvatarStack","sourcePath":"components/social/AvatarStack.jsx"},{"name":"EmptyState","sourcePath":"components/social/EmptyState.jsx"},{"name":"BookingWidget","sourcePath":"components/venue/BookingWidget.jsx"},{"name":"RatingStars","sourcePath":"components/venue/RatingStars.jsx"},{"name":"RestaurantCard","sourcePath":"components/venue/RestaurantCard.jsx"},{"name":"BookingFlowScreen","sourcePath":"ui_kits/app/BookingFlowScreen.jsx"},{"name":"ConfirmationScreen","sourcePath":"ui_kits/app/ConfirmationScreen.jsx"},{"name":"DiscoverScreen","sourcePath":"ui_kits/app/DiscoverScreen.jsx"},{"name":"MapCard","sourcePath":"ui_kits/app/MapCard.jsx"},{"name":"MyBookingsScreen","sourcePath":"ui_kits/app/MyBookingsScreen.jsx"},{"name":"OccasionScreen","sourcePath":"ui_kits/app/OccasionScreen.jsx"},{"name":"Onboarding","sourcePath":"ui_kits/app/Onboarding.jsx"},{"name":"Photo","sourcePath":"ui_kits/app/Photo.jsx"},{"name":"ProfileScreen","sourcePath":"ui_kits/app/ProfileScreen.jsx"},{"name":"SavedScreen","sourcePath":"ui_kits/app/SavedScreen.jsx"},{"name":"SearchScreen","sourcePath":"ui_kits/app/SearchScreen.jsx"},{"name":"SignInScreen","sourcePath":"ui_kits/app/SignInScreen.jsx"},{"name":"SplashScreen","sourcePath":"ui_kits/app/SplashScreen.jsx"},{"name":"VenueDetailScreen","sourcePath":"ui_kits/app/VenueDetailScreen.jsx"},{"name":"OperatorDashboard","sourcePath":"ui_kits/operator/OperatorDashboard.jsx"}],"sourceHashes":{"components/brand/DiningTrail.jsx":"c935ecf11fae","components/brand/Mashrabiya.jsx":"ab8b07f48b4c","components/core/Badge.jsx":"ed568a28002a","components/core/Button.jsx":"cf19b2f5e5de","components/core/Chip.jsx":"1a10e4e23ce7","components/core/Icon.jsx":"ae2548cf34c4","components/core/Input.jsx":"96688987e717","components/core/Skeleton.jsx":"e3915da52602","components/navigation/SearchBar.jsx":"c7ed70a7c917","components/navigation/TabBar.jsx":"a25f9c70f819","components/social/Avatar.jsx":"bc371201fd01","components/social/AvatarStack.jsx":"2b20351c43f3","components/social/EmptyState.jsx":"95f651c2fa3e","components/venue/BookingWidget.jsx":"ce7f023f4bd3","components/venue/RatingStars.jsx":"669af4e9d2e7","components/venue/RestaurantCard.jsx":"35a805dbb0f9","ui_kits/app/BookingFlowScreen.jsx":"40f50f2a29e2","ui_kits/app/ConfirmationScreen.jsx":"0de2bf0bdc13","ui_kits/app/DiscoverScreen.jsx":"7659983f9e93","ui_kits/app/MapCard.jsx":"32aae3e41568","ui_kits/app/MyBookingsScreen.jsx":"e444d99f3c70","ui_kits/app/OccasionScreen.jsx":"47787ebb229b","ui_kits/app/Onboarding.jsx":"e0024a94d245","ui_kits/app/Photo.jsx":"90452b5b3cfa","ui_kits/app/ProfileScreen.jsx":"516792cc3a82","ui_kits/app/SavedScreen.jsx":"d63825910224","ui_kits/app/SearchScreen.jsx":"5cb91b8df7da","ui_kits/app/SignInScreen.jsx":"0db4f079a771","ui_kits/app/SplashScreen.jsx":"771a8dff8355","ui_kits/app/VenueDetailScreen.jsx":"75826aaf93d7","ui_kits/operator/OperatorDashboard.jsx":"40a7d08e1e58"},"inlinedExternals":[],"unexposedExports":[{"name":"mashrabiyaUrl","sourcePath":"components/brand/Mashrabiya.jsx"}]} */

(() => {

const __ds_ns = (window.SAHRADesignSystem_5fbe17 = window.SAHRADesignSystem_5fbe17 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/brand/Mashrabiya.jsx
try { (() => {
// Mashrabiya — traditional Cairo carved-wood screen, abstracted to an eight-point-star lattice.
// SAHRA's signature texture: card dividers, empty/loading states, occasion backdrops. Distinctly
// Cairene, not a generic 'Arabic pattern'. Tiles seamlessly (rotated square corners meet neighbours).
function mashrabiyaUrl(color = 'rgba(221,95,53,0.5)', tile = 44) {
  const svg = "<svg xmlns='http://www.w3.org/2000/svg' width='" + tile + "' height='" + tile + "' viewBox='0 0 44 44'><g fill='none' stroke='" + color + "' stroke-width='1'><path d='M22 2 L42 22 L22 42 L2 22 Z'/><path d='M8 8 H36 V36 H8 Z'/></g></svg>";
  return "url(\"data:image/svg+xml," + encodeURIComponent(svg) + "\")";
}
function Mashrabiya({
  color = 'rgba(221,95,53,0.5)',
  opacity = 1,
  tile = 44,
  fade,
  style,
  children
}) {
  const mask = fade ? {
    WebkitMaskImage: 'radial-gradient(120% 100% at 50% 0%,#000,transparent 78%)',
    maskImage: 'radial-gradient(120% 100% at 50% 0%,#000,transparent 78%)'
  } : {};
  return /*#__PURE__*/React.createElement("div", {
    "aria-hidden": "true",
    style: {
      position: 'absolute',
      inset: 0,
      backgroundImage: mashrabiyaUrl(color, tile),
      backgroundSize: tile + 'px ' + tile + 'px',
      opacity,
      pointerEvents: 'none',
      ...mask,
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { mashrabiyaUrl, Mashrabiya });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/brand/Mashrabiya.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
function Badge({
  variant = 'neutral',
  children,
  style
}) {
  const v = {
    featured: {
      background: 'var(--terracotta)',
      color: '#fff'
    },
    gold: {
      background: 'var(--gold)',
      color: '#121212'
    },
    success: {
      background: 'rgba(76,122,79,.14)',
      color: 'var(--success)'
    },
    warning: {
      background: 'rgba(196,138,75,.18)',
      color: 'var(--gold-dark)'
    },
    error: {
      background: 'rgba(179,65,42,.12)',
      color: 'var(--error)'
    },
    neutral: {
      background: 'var(--surface-sunken)',
      color: 'var(--text-soft)'
    }
  }[variant];
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      padding: '4px 10px',
      borderRadius: 'var(--radius-pill)',
      fontSize: 11,
      fontWeight: 700,
      letterSpacing: '.08em',
      textTransform: 'uppercase',
      fontFamily: 'var(--font-latin)',
      ...v,
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const padMap = {
  sm: '8px 14px',
  md: '12px 20px',
  lg: '15px 26px'
};
const fsMap = {
  sm: 13,
  md: 14,
  lg: 15
};
function Button({
  variant = 'primary',
  size = 'md',
  pill,
  disabled,
  icon,
  children,
  style,
  ...rest
}) {
  const [pressed, setPressed] = React.useState(false);
  const [hover, setHover] = React.useState(false);
  const variants = {
    primary: {
      background: hover ? 'var(--terracotta-dark)' : 'var(--terracotta)',
      color: '#fff',
      border: 'none'
    },
    secondary: {
      background: hover ? 'var(--terracotta-tint)' : 'transparent',
      color: 'var(--terracotta)',
      border: '1.5px solid var(--terracotta)'
    },
    ghost: {
      background: hover ? 'var(--surface-sunken)' : 'transparent',
      color: 'var(--text-body)',
      border: 'none'
    },
    gold: {
      background: hover ? 'var(--gold-dark)' : 'var(--gold)',
      color: '#121212',
      border: 'none'
    }
  };
  const dis = disabled ? {
    background: 'var(--border)',
    color: 'var(--ink-faint)',
    border: 'none'
  } : {};
  return /*#__PURE__*/React.createElement("button", _extends({
    disabled: disabled,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => {
      setHover(false);
      setPressed(false);
    },
    onMouseDown: () => setPressed(true),
    onMouseUp: () => setPressed(false),
    style: {
      fontFamily: 'var(--font-latin)',
      fontWeight: 600,
      fontSize: fsMap[size],
      borderRadius: pill ? 'var(--radius-pill)' : 'var(--radius-md)',
      padding: padMap[size],
      cursor: disabled ? 'not-allowed' : 'pointer',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 8,
      transition: 'transform .05s ease,background .15s ease',
      transform: pressed ? 'scale(.98)' : 'none',
      ...variants[variant],
      ...dis,
      ...style
    }
  }, rest), icon, children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Chip.jsx
try { (() => {
function Chip({
  active,
  selected,
  icon,
  children,
  onClick,
  style
}) {
  const on = active || selected;
  const [pressed, setPressed] = React.useState(false);
  return /*#__PURE__*/React.createElement("button", {
    onClick: onClick,
    onPointerDown: () => setPressed(true),
    onPointerUp: () => setPressed(false),
    onPointerLeave: () => setPressed(false),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      padding: '8px 16px',
      borderRadius: 'var(--radius-pill)',
      fontSize: 13,
      fontWeight: 600,
      fontFamily: 'var(--font-latin)',
      cursor: 'pointer',
      border: on ? '1px solid transparent' : '1px solid var(--line)',
      background: on ? 'var(--terracotta)' : 'transparent',
      color: on ? '#fff' : 'var(--text-soft)',
      transform: pressed ? 'scale(.95)' : 'none',
      transition: 'transform .12s ease,background .15s ease,color .15s ease',
      ...style
    }
  }, icon, children);
}
Object.assign(__ds_scope, { Chip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Chip.jsx", error: String((e && e.message) || e) }); }

// components/core/Icon.jsx
try { (() => {
// SAHRA custom icon set — one uniform 1.6px line hand, drawn from Cairo dining culture
// (tea glass, mezze plate, lantern, shisha) alongside matching UI glyphs, so the whole
// app shares one voice instead of a generic third-party icon library.
const P = {
  // Cairo dining object family
  lantern: "<path d='M12 2.5v1.6'/><path d='M9 4.6h6'/><path d='M9.6 6.6h4.8l-.5-2h-3.8z'/><path d='M9.4 6.6C8.7 9.6 8.7 13 9.4 16h5.2c.7-3 .7-6.4 0-9.4'/><path d='M11 7.4v8M13 7.4v8'/><path d='M9.9 16h4.2M11 18.2h2'/>",
  tea: "<path d='M9.6 5.6l.8 8.3c.1 1 3.1 1 3.2 0l.8-8.3z'/><path d='M9.6 5.6h4.8'/><path d='M7.6 17.4c1 .8 7.8 .8 8.8 0'/><path d='M11 15.6v1.8h2v-1.8'/><path d='M10.8 2.6c.7.7-.7 1.3 0 2M13 2.6c.7.7-.7 1.3 0 2'/>",
  mezze: "<circle cx='12' cy='12' r='8'/><circle cx='12' cy='12' r='2.3'/><circle cx='12' cy='6.8' r='1.4'/><circle cx='16.4' cy='14.6' r='1.4'/><circle cx='7.6' cy='14.6' r='1.4'/>",
  shisha: "<path d='M10.5 3.6h3v2h-3z'/><path d='M9 6h6'/><path d='M12 6v7'/><circle cx='12' cy='16.5' r='3.5'/><path d='M12 9c3.4 0 4.4 1.8 5.4 3.8'/>",
  // UI glyphs — same weight & caps
  search: "<circle cx='10.5' cy='10.5' r='6.4'/><path d='M20 20l-4.9-4.9'/>",
  x: "<path d='M6 6l12 12M18 6L6 18'/>",
  heart: "<path d='M12 20C12 20 4.5 15.4 4.5 9.9 4.5 7.4 6.4 5.7 8.6 5.7 10 5.7 11.2 6.5 12 7.7 12.8 6.5 14 5.7 15.4 5.7 17.6 5.7 19.5 7.4 19.5 9.9 19.5 15.4 12 20 12 20Z'/>",
  user: "<circle cx='12' cy='8' r='3.4'/><path d='M5.5 19.5c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6'/>",
  users: "<circle cx='9' cy='8.5' r='3'/><path d='M3.5 19c0-3 2.5-5 5.5-5s5.5 2 5.5 5'/><path d='M16 6.2a3 3 0 0 1 0 5.6M17.6 14.2c1.9 .6 2.9 2.3 2.9 4.8'/>",
  "chevron-down": "<path d='M6.5 9.5L12 15l5.5-5.5'/>",
  "chevron-right": "<path d='M9.5 6.5L15 12l-5.5 5.5'/>",
  "chevron-left": "<path d='M14.5 6.5L9 12l5.5 5.5'/>",
  "chevron-up": "<path d='M6.5 14.5L12 9l5.5 5.5'/>",
  "arrow-left": "<path d='M14 6l-6 6 6 6M8.2 12H19'/>",
  "arrow-right": "<path d='M10 6l6 6-6 6M15.8 12H5'/>",
  "map-pin": "<path d='M12 21c4-4.6 6-7.7 6-10.6A6 6 0 0 0 6 10.4C6 13.3 8 16.4 12 21Z'/><circle cx='12' cy='10.3' r='2.2'/>",
  clock: "<circle cx='12' cy='12' r='7.5'/><path d='M12 8v4.2l3 1.8'/>",
  calendar: "<rect x='4.5' y='5.5' width='15' height='14' rx='2.5'/><path d='M4.5 9.5h15M8.5 3.5v3M15.5 3.5v3'/>",
  "calendar-plus": "<rect x='4.5' y='5.5' width='15' height='14' rx='2.5'/><path d='M4.5 9.5h15M8.5 3.5v3M15.5 3.5v3M12 12.5v4M10 14.5h4'/>",
  "calendar-check": "<rect x='4.5' y='5.5' width='15' height='14' rx='2.5'/><path d='M4.5 9.5h15M8.5 3.5v3M15.5 3.5v3M9 14l2 2 4-3.6'/>",
  check: "<path d='M5 12.5l4.5 4.5L19 7'/>",
  "circle-check": "<circle cx='12' cy='12' r='8.5'/><path d='M8 12.3l2.7 2.7L16 9.5'/>",
  image: "<rect x='4.5' y='5.5' width='15' height='13' rx='2.5'/><circle cx='9' cy='10' r='1.6'/><path d='M6 17l4-4 3 3 2.5-2.5L19 15.5'/>",
  compass: "<circle cx='12' cy='12' r='8'/><path d='M15 9l-1.6 4.4L9 15l1.6-4.4z'/>",
  share: "<circle cx='7' cy='12' r='2'/><circle cx='17' cy='6.5' r='2'/><circle cx='17' cy='17.5' r='2'/><path d='M8.8 11l6.4-3.5M8.8 13l6.4 3.5'/>",
  phone: "<path d='M7 4.5c1 0 1.6.4 2 1.5l.9 2.4c.3.9 0 1.4-.6 1.9l-1 .8c1 2 2.3 3.3 4.3 4.3l.8-1c.5-.6 1-.9 1.9-.6l2.4.9c1.1.4 1.5 1 1.5 2 0 2.4-2 3.3-4 2.8C10 20.5 3.5 14 3.6 8.6 3.6 6.6 4.3 4.5 7 4.5z'/>",
  plus: "<path d='M12 5.5v13M5.5 12h13'/>",
  bell: "<path d='M6.5 17c1-1 1.5-2.3 1.5-4v-2a4 4 0 0 1 8 0v2c0 1.7.5 3 1.5 4z'/><path d='M10 17v.4a2 2 0 0 0 4 0V17'/>",
  tag: "<path d='M4.5 10.5v-5a1 1 0 0 1 1-1h5l9 9a1.4 1.4 0 0 1 0 2l-5 5a1.4 1.4 0 0 1-2 0z'/><circle cx='8.5' cy='8.5' r='1.4'/>",
  ticket: "<path d='M4.5 6.5h15v3.2a2.3 2.3 0 0 0 0 4.6v3.2h-15v-3.2a2.3 2.3 0 0 0 0-4.6z'/><path d='M14.5 6.5v11' stroke-dasharray='2 2.4'/>",
  "credit-card": "<rect x='3.5' y='6' width='17' height='12' rx='2.5'/><path d='M3.5 10h17'/>",
  globe: "<circle cx='12' cy='12' r='8'/><path d='M4 12h16M12 4c2.6 2.2 2.6 13.8 0 16M12 4c-2.6 2.2-2.6 13.8 0 16'/>",
  "circle-help": "<circle cx='12' cy='12' r='8.5'/><path d='M9.7 9.6a2.3 2.3 0 0 1 4.4.8c0 1.6-2.1 1.8-2.1 3.1'/><path d='M12 16.6h.01'/>",
  "layout-grid": "<rect x='4.5' y='4.5' width='6' height='6' rx='1.5'/><rect x='13.5' y='4.5' width='6' height='6' rx='1.5'/><rect x='4.5' y='13.5' width='6' height='6' rx='1.5'/><rect x='13.5' y='13.5' width='6' height='6' rx='1.5'/>",
  "moon-star": "<path d='M18.5 14.2A7 7 0 1 1 9.8 5.5a5.5 5.5 0 0 0 8.7 8.7z'/><path d='M17.3 3.8l.6 1.4 1.4.6-1.4.6-.6 1.4-.6-1.4-1.4-.6 1.4-.6z'/>",
  star: "<path d='M12 4.6l2.2 4.6 5 .7-3.6 3.5.9 5-4.5-2.4-4.5 2.4.9-5L4.8 9.9l5-.7z'/>",
  spark: "<path d='M12 4l1.4 4.6L18 10l-4.6 1.4L12 16l-1.4-4.6L6 10l4.6-1.4z'/>",
  "calendar-check2": ""
};
function Icon({
  name,
  size = 20,
  style
}) {
  const inner = P[name];
  if (inner) return /*#__PURE__*/React.createElement("svg", {
    viewBox: "0 0 24 24",
    width: size,
    height: size,
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.6,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    "aria-hidden": "true",
    style: {
      flexShrink: 0,
      display: 'inline-block',
      ...style
    },
    dangerouslySetInnerHTML: {
      __html: inner
    }
  });
  const m = 'url(https://unpkg.com/lucide-static@0.462.0/icons/' + name + '.svg)';
  return /*#__PURE__*/React.createElement("span", {
    "aria-hidden": "true",
    style: {
      width: size,
      height: size,
      display: 'inline-block',
      flexShrink: 0,
      background: 'currentColor',
      WebkitMaskImage: m,
      maskImage: m,
      WebkitMaskSize: 'contain',
      maskSize: 'contain',
      WebkitMaskRepeat: 'no-repeat',
      maskRepeat: 'no-repeat',
      WebkitMaskPosition: 'center',
      maskPosition: 'center',
      ...style
    }
  });
}
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Icon.jsx", error: String((e && e.message) || e) }); }

// components/brand/DiningTrail.jsx
try { (() => {
// Dining trail — past visits as a connected string of lantern-dot nodes, not a flat photo grid.
// SAHRA's product is connected memories, not isolated bookings; the trail makes that literal.
function DiningTrail({
  visits = [],
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      fontFamily: 'var(--font-latin)',
      ...style
    }
  }, visits.map((v, i) => {
    const last = i === visits.length - 1;
    const glow = i === 0;
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        display: 'flex',
        gap: 16,
        paddingBottom: last ? 0 : 22,
        position: 'relative'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'relative',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center'
      }
    }, !last && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        top: 26,
        bottom: -22,
        width: 2,
        background: 'linear-gradient(var(--line),transparent)'
      }
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        width: 26,
        height: 26,
        borderRadius: '50%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
        color: glow ? '#121212' : 'var(--gold)',
        background: glow ? 'var(--gold)' : 'transparent',
        border: glow ? 'none' : '1.5px solid var(--line)',
        boxShadow: glow ? '0 0 18px rgba(224,169,109,.55)' : 'none',
        position: 'relative',
        zIndex: 1
      }
    }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "lantern",
      size: 16
    }))), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        paddingTop: 2
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-display)',
        fontSize: 17,
        fontWeight: 600,
        letterSpacing: '-.01em',
        color: 'var(--text-body)'
      }
    }, v.name), /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 12,
        color: 'var(--text-faint)',
        marginTop: 2
      }
    }, v.date, v.note ? ' · ' + v.note : '')));
  }));
}
Object.assign(__ds_scope, { DiningTrail });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/brand/DiningTrail.jsx", error: String((e && e.message) || e) }); }

// components/core/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Input({
  label,
  help,
  error,
  variant = 'box',
  style,
  inputStyle,
  ...rest
}) {
  const [focus, setFocus] = React.useState(false);
  const bc = error ? 'var(--error)' : focus ? 'var(--terracotta)' : 'var(--line)';
  const box = {
    width: '100%',
    fontFamily: 'var(--font-latin)',
    fontSize: 14,
    padding: '12px 14px',
    border: '1.5px solid ' + bc,
    borderRadius: 'var(--radius-md)',
    background: 'var(--surface-card)',
    color: 'var(--text-body)',
    outline: 'none',
    boxShadow: focus && !error ? '0 0 0 3px var(--terracotta-tint)' : 'none',
    boxSizing: 'border-box'
  };
  const line = {
    width: '100%',
    fontFamily: 'var(--font-latin)',
    fontSize: 14,
    padding: '8px 0',
    border: 'none',
    borderBottom: '1.5px solid ' + bc,
    background: 'transparent',
    color: 'var(--text-body)',
    outline: 'none',
    boxSizing: 'border-box'
  };
  const isLine = variant === 'line';
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'block',
      fontFamily: 'var(--font-latin)',
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontSize: isLine ? 10 : 13,
      fontWeight: 600,
      letterSpacing: isLine ? 'var(--tracking-overline)' : 'normal',
      textTransform: isLine ? 'uppercase' : 'none',
      color: isLine ? 'var(--text-faint)' : 'var(--text-body)',
      marginBottom: 6
    }
  }, label), /*#__PURE__*/React.createElement("input", _extends({}, rest, {
    onFocus: e => {
      setFocus(true);
      rest.onFocus && rest.onFocus(e);
    },
    onBlur: e => {
      setFocus(false);
      rest.onBlur && rest.onBlur(e);
    },
    style: {
      ...(isLine ? line : box),
      ...inputStyle
    }
  })), (error || help) && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontSize: 12,
      marginTop: 6,
      color: error ? 'var(--error)' : 'var(--text-faint)'
    }
  }, error || help));
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Input.jsx", error: String((e && e.message) || e) }); }

// components/core/Skeleton.jsx
try { (() => {
// Loading placeholder with the signature mashrabiya shimmer — the lattice glints as light sweeps across.
function Skeleton({
  width = '100%',
  height = 16,
  radius = 'var(--radius-md)',
  lattice = false,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width,
      height,
      borderRadius: radius,
      background: 'var(--surface-sunken)',
      overflow: 'hidden',
      ...style
    }
  }, /*#__PURE__*/React.createElement("style", null, `@keyframes sahraShimmer{0%{transform:translateX(-100%)}100%{transform:translateX(100%)}}`), lattice && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      backgroundImage: __ds_scope.mashrabiyaUrl('currentColor', 36),
      color: 'var(--text-body)',
      opacity: .05
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'linear-gradient(100deg,transparent 30%,rgba(224,169,109,.16) 50%,transparent 70%)',
      animation: 'sahraShimmer 1.6s ease-in-out infinite'
    }
  }));
}
function SkeletonCard({
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: 250,
      border: '1px solid var(--line)',
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
      background: 'var(--surface-card)',
      ...style
    }
  }, /*#__PURE__*/React.createElement(Skeleton, {
    height: 140,
    radius: 0,
    lattice: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 14,
      display: 'flex',
      flexDirection: 'column',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(Skeleton, {
    width: "70%",
    height: 18
  }), /*#__PURE__*/React.createElement(Skeleton, {
    width: "45%",
    height: 12
  }), /*#__PURE__*/React.createElement(Skeleton, {
    width: "85%",
    height: 12
  })));
}
Object.assign(__ds_scope, { Skeleton, SkeletonCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Skeleton.jsx", error: String((e && e.message) || e) }); }

// components/navigation/SearchBar.jsx
try { (() => {
function SearchBar({
  placeholder = 'Search',
  location = 'Cairo',
  onChange,
  style,
  inputStyle
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      background: 'var(--surface-sunken)',
      border: '1px solid var(--line)',
      borderRadius: 'var(--radius-pill)',
      padding: '10px 16px',
      fontFamily: 'var(--font-latin)',
      boxSizing: 'border-box',
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-faint)',
      display: 'flex'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "search",
    size: 16
  })), /*#__PURE__*/React.createElement("input", {
    placeholder: placeholder,
    onChange: onChange,
    style: {
      flex: 1,
      minWidth: 0,
      background: 'transparent',
      border: 'none',
      outline: 'none',
      color: 'var(--text-body)',
      fontSize: 14,
      fontFamily: 'var(--font-latin)',
      ...inputStyle
    }
  }), location && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      fontWeight: 600,
      color: 'var(--gold)'
    }
  }, location));
}
Object.assign(__ds_scope, { SearchBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/SearchBar.jsx", error: String((e && e.message) || e) }); }

// components/navigation/TabBar.jsx
try { (() => {
const defaults = [{
  id: 'discover',
  label: 'Discover',
  icon: 'layout-grid'
}, {
  id: 'search',
  label: 'Search',
  icon: 'search'
}, {
  id: 'account',
  label: 'Account',
  icon: 'user'
}];
function TabBar({
  items = defaults,
  active,
  onChange,
  style
}) {
  const [cur, setCur] = React.useState(active || items[0].id);
  const sel = active !== undefined ? active : cur;
  return /*#__PURE__*/React.createElement("nav", {
    style: {
      display: 'flex',
      background: 'var(--surface-page)',
      borderTop: '1px solid var(--line)',
      padding: '10px 8px 14px',
      boxSizing: 'border-box',
      ...style
    }
  }, items.map(it => {
    const on = sel === it.id;
    return /*#__PURE__*/React.createElement("button", {
      key: it.id,
      onClick: () => {
        setCur(it.id);
        onChange && onChange(it.id);
      },
      style: {
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 4,
        background: 'none',
        border: 'none',
        cursor: 'pointer',
        color: on ? 'var(--terracotta)' : 'var(--text-faint)',
        fontFamily: 'var(--font-latin)',
        padding: 0
      }
    }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: it.icon,
      size: 20
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 10,
        fontWeight: 600
      }
    }, it.label), /*#__PURE__*/React.createElement("span", {
      style: {
        width: 4,
        height: 4,
        borderRadius: 2,
        background: on ? 'var(--terracotta)' : 'transparent'
      }
    }));
  }));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/TabBar.jsx", error: String((e && e.message) || e) }); }

// components/social/Avatar.jsx
try { (() => {
function Avatar({
  name = '',
  src,
  size = 36,
  style
}) {
  const initials = name.split(' ').map(w => w[0]).filter(Boolean).slice(0, 2).join('').toUpperCase();
  return /*#__PURE__*/React.createElement("span", {
    style: {
      width: size,
      height: size,
      borderRadius: '50%',
      overflow: 'hidden',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'var(--terracotta-tint)',
      color: 'var(--terracotta-dark)',
      fontWeight: 700,
      fontSize: Math.round(size * .36),
      fontFamily: 'var(--font-latin)',
      flexShrink: 0,
      boxSizing: 'border-box',
      ...style
    }
  }, src ? /*#__PURE__*/React.createElement("img", {
    src: src,
    alt: name,
    style: {
      width: '100%',
      height: '100%',
      objectFit: 'cover'
    }
  }) : initials);
}
Object.assign(__ds_scope, { Avatar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/social/Avatar.jsx", error: String((e && e.message) || e) }); }

// components/social/AvatarStack.jsx
try { (() => {
function AvatarStack({
  people = [],
  max = 3,
  size = 32,
  label,
  style
}) {
  const shown = people.slice(0, max);
  const extra = people.length - shown.length;
  const ring = {
    border: '2px solid var(--surface-page)'
  };
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      fontFamily: 'var(--font-latin)',
      ...style
    }
  }, shown.map((p, i) => /*#__PURE__*/React.createElement(__ds_scope.Avatar, {
    key: i,
    name: p.name,
    src: p.src,
    size: size,
    style: {
      ...ring,
      marginLeft: i ? -Math.round(size * .3) : 0
    }
  })), extra > 0 && /*#__PURE__*/React.createElement("span", {
    style: {
      width: size,
      height: size,
      borderRadius: '50%',
      background: 'var(--surface-sunken)',
      color: 'var(--text-soft)',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontSize: 11,
      fontWeight: 700,
      marginLeft: -Math.round(size * .3),
      boxSizing: 'border-box',
      ...ring
    }
  }, "+", extra), label && /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: 10,
      fontSize: 13,
      color: 'var(--text-soft)'
    }
  }, label));
}
Object.assign(__ds_scope, { AvatarStack });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/social/AvatarStack.jsx", error: String((e && e.message) || e) }); }

// components/social/EmptyState.jsx
try { (() => {
function EmptyState({
  icon = 'moon-star',
  title,
  message,
  actionLabel,
  onAction,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      textAlign: 'center',
      padding: '40px 24px',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 8,
      fontFamily: 'var(--font-latin)',
      ...style
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Mashrabiya, {
    color: "var(--text-body)",
    opacity: 0.045,
    tile: 46,
    fade: true
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 56,
      height: 56,
      borderRadius: '50%',
      background: 'var(--surface-sunken)',
      color: 'var(--terracotta)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 24
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 19,
      fontWeight: 600,
      letterSpacing: '-.01em',
      marginTop: 8,
      color: 'var(--text-body)'
    }
  }, title), message && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--text-soft)',
      maxWidth: 300,
      lineHeight: 1.5
    }
  }, message), actionLabel && /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "sm",
    style: {
      marginTop: 8
    },
    onClick: onAction
  }, actionLabel));
}
Object.assign(__ds_scope, { EmptyState });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/social/EmptyState.jsx", error: String((e && e.message) || e) }); }

// components/venue/BookingWidget.jsx
try { (() => {
function BookingWidget({
  venue = 'Layali Lounge',
  times = ['7:30 PM', '9:00 PM', '10:30 PM'],
  defaultTime,
  defaultParty = 2,
  onBook,
  width = 320,
  style
}) {
  const [party, setParty] = React.useState(defaultParty);
  const [time, setTime] = React.useState(defaultTime || times[1]);
  const [booked, setBooked] = React.useState(false);
  const step = d => setParty(p => Math.max(1, Math.min(12, p + d)));
  const stepBtn = {
    width: 32,
    height: 32,
    borderRadius: '50%',
    border: '1px solid var(--line)',
    background: 'var(--surface-card)',
    color: 'var(--text-body)',
    fontSize: 16,
    cursor: 'pointer',
    fontFamily: 'var(--font-latin)',
    lineHeight: 1
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width,
      background: 'var(--surface-card)',
      border: '1px solid var(--line)',
      borderRadius: 'var(--radius-lg)',
      boxShadow: 'var(--shadow-2)',
      padding: 20,
      fontFamily: 'var(--font-latin)',
      boxSizing: 'border-box',
      ...style
    }
  }, booked ? /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      padding: '8px 0',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--success)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "circle-check",
    size: 32
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 17,
      fontWeight: 700,
      color: 'var(--text-body)'
    }
  }, "You\u2019re in."), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--text-soft)',
      lineHeight: 1.5
    }
  }, "Your table for ", party, " is set for ", time, " at ", venue, ". We told them you\u2019re coming."), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "ghost",
    size: "sm",
    onClick: () => setBooked(false)
  }, "Change plans")) : /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      fontWeight: 700,
      letterSpacing: 'var(--tracking-overline)',
      textTransform: 'uppercase',
      color: 'var(--terracotta)',
      marginBottom: 12
    }
  }, "Tonight \xB7 ", venue), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      marginBottom: 14
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      fontWeight: 600,
      color: 'var(--text-body)'
    }
  }, "Party size"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: stepBtn,
    onClick: () => step(-1)
  }, "\u2212"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 15,
      fontWeight: 700,
      minWidth: 16,
      textAlign: 'center',
      color: 'var(--text-body)'
    }
  }, party), /*#__PURE__*/React.createElement("button", {
    style: stepBtn,
    onClick: () => step(1)
  }, "+"))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap',
      marginBottom: 16
    }
  }, times.map(t => /*#__PURE__*/React.createElement(__ds_scope.Chip, {
    key: t,
    active: t === time,
    onClick: () => setTime(t)
  }, t))), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    style: {
      width: '100%'
    },
    onClick: () => {
      setBooked(true);
      onBook && onBook({
        party,
        time
      });
    }
  }, "Book this table"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)',
      textAlign: 'center',
      marginTop: 10
    }
  }, "Free cancellation up to 2 hours before.")));
}
Object.assign(__ds_scope, { BookingWidget });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/venue/BookingWidget.jsx", error: String((e && e.message) || e) }); }

// components/venue/RatingStars.jsx
try { (() => {
function RatingStars({
  rating = 0,
  reviews,
  size = 13,
  showValue = true,
  style
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 5,
      fontFamily: 'var(--font-latin)',
      fontSize: size,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--terracotta)',
      fontWeight: 700,
      letterSpacing: '.5px'
    }
  }, "\u2605"), showValue && /*#__PURE__*/React.createElement("b", {
    style: {
      color: 'var(--terracotta)',
      fontWeight: 700
    }
  }, rating), reviews != null && /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-faint)'
    }
  }, "(", reviews, ")"));
}
Object.assign(__ds_scope, { RatingStars });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/venue/RatingStars.jsx", error: String((e && e.message) || e) }); }

// components/venue/RestaurantCard.jsx
try { (() => {
function RestaurantCard({
  name,
  rating,
  reviews,
  cuisine,
  price = '$$$',
  neighbourhood,
  image,
  tone = 'terrace',
  featured,
  availability,
  saved,
  onSave,
  onClick,
  width = 280,
  imageHeight = 160,
  style
}) {
  const bg = image ? '#2E2219 url(' + image + ') center/cover' : 'linear-gradient(150deg,#4A392C,#2C2018)';
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      width,
      background: 'var(--surface-card)',
      border: '1px solid var(--line)',
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
      cursor: onClick ? 'pointer' : 'default',
      fontFamily: 'var(--font-latin)',
      boxShadow: 'var(--shadow-1)',
      boxSizing: 'border-box',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      height: imageHeight,
      background: bg
    }
  }, !image && /*#__PURE__*/React.createElement(__ds_scope.Mashrabiya, {
    color: "rgba(253,251,247,0.09)",
    tile: 38
  }), !image && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      color: 'rgba(253,251,247,.16)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "image",
    size: 30
  })), featured && /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    variant: "featured",
    style: {
      position: 'absolute',
      top: 12,
      left: 12
    }
  }, "Featured"), /*#__PURE__*/React.createElement("button", {
    onClick: e => {
      e.stopPropagation();
      onSave && onSave();
    },
    style: {
      position: 'absolute',
      top: 10,
      right: 10,
      width: 34,
      height: 34,
      borderRadius: '50%',
      border: 'none',
      background: 'rgba(20,12,8,.42)',
      backdropFilter: 'blur(4px)',
      cursor: 'pointer',
      color: saved ? 'var(--gold)' : '#FDFBF7',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      overflow: 'visible'
    }
  }, /*#__PURE__*/React.createElement("style", null, `@keyframes sahraHeartPop{0%{transform:scale(.4)}55%{transform:scale(1.35)}100%{transform:scale(1)}}@keyframes sahraHeartRing{0%{transform:scale(.4);opacity:.8}100%{transform:scale(1.9);opacity:0}}`), saved && /*#__PURE__*/React.createElement("span", {
    "aria-hidden": "true",
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: '50%',
      border: '1.5px solid var(--gold)',
      animation: 'sahraHeartRing .5s ease-out both',
      pointerEvents: 'none'
    }
  }), /*#__PURE__*/React.createElement("span", {
    key: saved ? 's' : 'u',
    style: {
      display: 'flex',
      animation: saved ? 'sahraHeartPop .4s cubic-bezier(.34,1.6,.5,1) both' : 'none'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "heart",
    size: 17,
    style: saved ? {
      color: 'var(--gold)'
    } : {}
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      height: 60,
      background: 'linear-gradient(transparent,rgba(20,12,8,.55))'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '13px 16px 16px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 19,
      fontWeight: 600,
      color: 'var(--text-body)',
      letterSpacing: '-.01em'
    }
  }, name), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      marginTop: 5,
      fontSize: 12,
      color: 'var(--text-faint)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.RatingStars, {
    rating: rating,
    reviews: reviews,
    size: 12
  }), /*#__PURE__*/React.createElement("span", null, "\xB7 ", cuisine, " \xB7 ", price)), neighbourhood && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)',
      marginTop: 3,
      display: 'flex',
      alignItems: 'center',
      gap: 4
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "map-pin",
    size: 12
  }), neighbourhood), availability && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 12,
      paddingTop: 12,
      borderTop: '1px solid var(--line)',
      fontSize: 12,
      fontWeight: 600,
      color: 'var(--text-soft)',
      display: 'flex',
      alignItems: 'center',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "clock",
    size: 14,
    style: {
      color: 'var(--terracotta)'
    }
  }), availability)));
}
Object.assign(__ds_scope, { RestaurantCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/venue/RestaurantCard.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/MapCard.jsx
try { (() => {
let leafletP = null;
function loadLeaflet() {
  if (window.L) return Promise.resolve(window.L);
  if (leafletP) return leafletP;
  leafletP = new Promise((res, rej) => {
    const css = document.createElement('link');
    css.rel = 'stylesheet';
    css.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
    css.integrity = 'sha384-sHL9NAb7lN7rfvG5lfHpm643Xkcjzp4jFvuavGOndn6pjVqS6ny56CAt3nsEVT4H';
    css.crossOrigin = 'anonymous';
    document.head.appendChild(css);
    const s = document.createElement('script');
    s.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
    s.integrity = 'sha384-cxOPjt7s7Iz04uaHJceBmS+qpjv2JkIHNVcuOrM+YHwZOmJGBXI00mdUXEq65HTH';
    s.crossOrigin = 'anonymous';
    s.onload = () => res(window.L);
    s.onerror = rej;
    document.head.appendChild(s);
  });
  return leafletP;
}
const DEFAULT_PINS = [{
  name: 'Layali Lounge',
  pos: [30.0622, 31.2185],
  time: '9:00'
}, {
  name: 'Sequoia',
  pos: [30.0742, 31.2249],
  time: '8:30'
}, {
  name: 'Kazoku',
  pos: [30.0585, 31.2228],
  time: '10:00'
}];
// Real street map of Zamalek, Cairo (Leaflet + OpenStreetMap) with the SAHRA warm-paper tile
// treatment, terracotta availability pins, and a gold "you" beacon. Falls back to a lattice
// placeholder until tiles arrive.
function MapCard({
  height = 190,
  city = 'CAIRO',
  pins = DEFAULT_PINS,
  center = [30.0645, 31.2215],
  zoom = 14,
  onPin,
  interactive = true
}) {
  const ref = React.useRef(null);
  const mapRef = React.useRef(null);
  const [ready, setReady] = React.useState(false);
  React.useEffect(() => {
    let dead = false;
    loadLeaflet().then(L => {
      if (dead || !ref.current || mapRef.current) return;
      const map = L.map(ref.current, {
        zoomControl: false,
        scrollWheelZoom: false,
        dragging: interactive,
        attributionControl: true
      });
      map.attributionControl.setPrefix(false);
      map.setView(center, zoom);
      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
      }).addTo(map);
      L.marker(center, {
        icon: L.divIcon({
          className: '',
          html: '<span class="sahra-you"></span>',
          iconSize: [14, 14],
          iconAnchor: [7, 7]
        }),
        interactive: false
      }).addTo(map);
      pins.forEach(p => {
        const m = L.marker(p.pos, {
          icon: L.divIcon({
            className: '',
            html: '<span class="sahra-pin">' + p.time + '</span>',
            iconSize: [0, 0],
            iconAnchor: [0, 26]
          })
        }).addTo(map);
        if (onPin) m.on('click', () => onPin(p));
      });
      mapRef.current = map;
      map.whenReady(() => {
        if (!dead) setTimeout(() => setReady(true), 150);
      });
    }).catch(() => {});
    return () => {
      dead = true;
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, []);
  React.useEffect(() => {
    if (mapRef.current) setTimeout(() => mapRef.current.invalidateSize(), 320);
  }, [height]);
  return /*#__PURE__*/React.createElement("div", {
    className: "sahra-map",
    style: {
      position: 'relative',
      height,
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
      border: '1px solid var(--line)',
      background: 'var(--surface-card)',
      transition: 'height .3s cubic-bezier(.2,.7,.3,1)'
    }
  }, /*#__PURE__*/React.createElement("style", null, `
      .sahra-map .leaflet-tile{filter:sepia(.32) saturate(.72) hue-rotate(-10deg) brightness(1.04) contrast(.92)}
      .theme-night .sahra-map .leaflet-tile{filter:invert(1) hue-rotate(185deg) brightness(.82) saturate(.55) sepia(.22)}
      .sahra-map .leaflet-container{background:var(--surface-sunken);font-family:var(--font-latin)}
      .sahra-map .leaflet-control-attribution{background:rgba(253,251,247,.7);font-size:8px;color:#8A7563}
      .theme-night .sahra-map .leaflet-control-attribution{background:rgba(26,18,12,.7);color:#A38D7C}
      .sahra-pin{display:inline-block;background:var(--terracotta);color:#fff;font-size:11px;font-weight:700;font-family:var(--font-latin);padding:4px 9px;border-radius:999px;white-space:nowrap;box-shadow:0 3px 10px rgba(0,0,0,.3);position:relative;transform:translateX(-50%)}
      .sahra-pin::after{content:'';position:absolute;left:50%;bottom:-4px;width:8px;height:8px;background:var(--terracotta);transform:translateX(-50%) rotate(45deg);border-radius:1px}
      .sahra-you{display:block;width:14px;height:14px;border-radius:50%;background:var(--gold);border:2.5px solid #fff;box-shadow:0 0 0 0 rgba(224,169,109,.55);animation:sahraYou 2.2s ease-out infinite}
      @keyframes sahraYou{0%{box-shadow:0 0 0 0 rgba(224,169,109,.55)}100%{box-shadow:0 0 0 16px rgba(224,169,109,0)}}
    `), /*#__PURE__*/React.createElement("div", {
    ref: ref,
    style: {
      position: 'absolute',
      inset: 0,
      zIndex: 0
    }
  }), !ready && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'var(--surface-sunken)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 2
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      backgroundImage: __ds_scope.mashrabiyaUrl('currentColor', 40),
      color: 'var(--text-body)',
      opacity: .05
    }
  }), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "map-pin",
    size: 22,
    style: {
      color: 'var(--text-faint)'
    }
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      insetInlineStart: 12,
      top: 10,
      fontSize: 10,
      fontWeight: 700,
      letterSpacing: '.2em',
      color: 'var(--text-soft)',
      background: 'var(--surface-card)',
      padding: '4px 10px',
      borderRadius: 999,
      border: '1px solid var(--line)',
      zIndex: 3
    }
  }, city));
}
Object.assign(__ds_scope, { MapCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/MapCard.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Photo.jsx
try { (() => {
function Photo({
  src,
  image,
  height,
  radius = 0,
  label,
  children,
  gradientOverlay,
  cue = true,
  style
}) {
  const url = src || image;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width: '100%',
      height,
      borderRadius: radius,
      overflow: 'hidden',
      background: url ? '#2E2219 url(' + url + ') center/cover' : 'linear-gradient(150deg,#4A392C,#2C2018)',
      ...style
    }
  }, !url && /*#__PURE__*/React.createElement(__ds_scope.Mashrabiya, {
    color: "rgba(253,251,247,0.09)",
    tile: 40
  }), !url && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'radial-gradient(120% 100% at 30% 0%,rgba(255,255,255,.05),transparent 60%)'
    }
  }), !url && cue && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      color: 'rgba(253,251,247,.18)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "image",
    size: Math.max(22, Math.min(40, (parseInt(height) || 120) * 0.28))
  })), gradientOverlay && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      height: '62%',
      background: 'linear-gradient(transparent,rgba(20,12,8,.82))'
    }
  }), label && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: 12,
      top: 12,
      fontSize: 10,
      fontWeight: 700,
      letterSpacing: '.16em',
      textTransform: 'uppercase',
      color: 'rgba(253,251,247,.8)'
    }
  }, label), children);
}
Object.assign(__ds_scope, { Photo });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Photo.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/BookingFlowScreen.jsx
try { (() => {
const IMG = id => 'https://images.unsplash.com/photo-' + id + '?w=900&q=80&auto=format&fit=crop';
const T = {
  en: {
    title: 'Book a table',
    date: 'Date',
    party: 'Party size',
    time: 'Time',
    guest: 'guest',
    guests: 'guests',
    confirm: 'Confirm for',
    at: 'at',
    pm: 'PM',
    free: 'Free cancellation up to 2 hours before.',
    cuisine: 'Levantine',
    full: 'Fully booked',
    notify: 'Notify me',
    notifying: 'Watching',
    notifyHint: "We'll ping you if a table frees up.",
    days: [['Tonight', 'Wed 21'], ['Thu', '22'], ['Fri', '23'], ['Sat', '24'], ['Sun', '25'], ['Mon', '26']]
  },
  ar: {
    title: 'احجز طاولة',
    date: 'التاريخ',
    party: 'عدد الأفراد',
    time: 'الوقت',
    guest: 'فرد',
    guests: 'أفراد',
    confirm: 'أكّد لـ',
    at: 'الساعة',
    pm: 'م',
    free: 'إلغاء مجاني حتى ساعتين قبل الموعد.',
    cuisine: 'شامي',
    full: 'مكتمل',
    notify: 'بلّغني',
    notifying: 'بنراقب',
    notifyHint: 'هنبلّغك لو فضيت طاولة.',
    days: [['الليلة', 'الأربع 21'], ['الخميس', '22'], ['الجمعة', '23'], ['السبت', '24'], ['الأحد', '25'], ['الاثنين', '26']]
  }
};
const slots = ['6:00', '6:30', '7:00', '7:30', '7:45', '8:00', '8:30', '9:00', '9:15', '9:45', '10:00', '10:30'];
const fullSlots = ['7:30', '8:00', '8:30'];
function BookingFlowScreen({
  venue = {},
  onBack,
  onConfirm,
  lang = 'en'
}) {
  const ar = lang === 'ar';
  const t = T[lang] || T.en;
  const L = x => x && typeof x === 'object' ? ar ? x.ar : x.en : x;
  const v = {
    name: {
      en: 'Layali Lounge',
      ar: 'ليالي لاونج'
    },
    image: IMG('1414235077428-338989a2e8c0'),
    neighbourhood: {
      en: 'Zamalek',
      ar: 'الزمالك'
    },
    ...venue
  };
  const [day, setDay] = React.useState(0);
  const [party, setParty] = React.useState(2);
  const [time, setTime] = React.useState('9:00');
  const [watching, setWatching] = React.useState({});
  const toggleWatch = s => setWatching(w => ({
    ...w,
    [s]: !w[s]
  }));
  const step = d => setParty(p => Math.max(1, Math.min(12, p + d)));
  const stepBtn = {
    width: 40,
    height: 40,
    borderRadius: '50%',
    border: '1px solid var(--line)',
    background: 'var(--surface-card)',
    color: 'var(--text-body)',
    fontSize: 20,
    cursor: 'pointer',
    lineHeight: 1
  };
  return /*#__PURE__*/React.createElement("div", {
    dir: ar ? 'rtl' : 'ltr',
    style: {
      height: '100%',
      display: 'flex',
      flexDirection: 'column',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: '20px 20px 14px'
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: onBack,
    style: {
      background: 'none',
      border: 'none',
      color: 'var(--text-body)',
      cursor: 'pointer',
      display: 'flex',
      padding: 0
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: ar ? 'arrow-right' : 'arrow-left',
    size: 22
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 21,
      fontWeight: 600,
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, t.title)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: 'auto',
      padding: '0 20px 20px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 12,
      alignItems: 'center',
      background: 'var(--surface-card)',
      border: '1px solid var(--line)',
      borderRadius: 'var(--radius-lg)',
      padding: 10,
      marginBottom: 22
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 56
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Photo, {
    image: v.image,
    height: 56,
    radius: 10
  })), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 17,
      fontWeight: 600,
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, L(v.name)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)'
    }
  }, L(v.neighbourhood), " \xB7 ", t.cuisine))), /*#__PURE__*/React.createElement(Label, {
    ar: ar
  }, t.date), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      overflowX: 'auto',
      paddingBottom: 4,
      marginBottom: 22
    }
  }, t.days.map(([d, n], i) => /*#__PURE__*/React.createElement("button", {
    key: i,
    onClick: () => setDay(i),
    style: {
      flex: '0 0 auto',
      minWidth: 64,
      padding: '12px 0',
      borderRadius: 'var(--radius-md)',
      border: '1px solid ' + (day === i ? 'transparent' : 'var(--line)'),
      background: day === i ? 'var(--terracotta)' : 'transparent',
      color: day === i ? '#fff' : 'var(--text-soft)',
      cursor: 'pointer',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      opacity: .85
    }
  }, d), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      fontWeight: 700
    }
  }, n)))), /*#__PURE__*/React.createElement(Label, {
    ar: ar
  }, t.party), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 24,
      margin: '6px 0 24px'
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: stepBtn,
    onClick: () => step(-1)
  }, "\u2212"), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 32,
      fontWeight: 700
    }
  }, party), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      color: 'var(--text-faint)'
    }
  }, party === 1 ? t.guest : t.guests)), /*#__PURE__*/React.createElement("button", {
    style: stepBtn,
    onClick: () => step(1)
  }, "+")), /*#__PURE__*/React.createElement(Label, {
    ar: ar
  }, t.time), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap',
      marginTop: 4
    }
  }, slots.map(s => {
    const full = fullSlots.includes(s);
    if (!full) return /*#__PURE__*/React.createElement(__ds_scope.Chip, {
      key: s,
      active: time === s,
      onClick: () => setTime(s)
    }, s, " ", t.pm);
    const on = !!watching[s];
    return /*#__PURE__*/React.createElement("button", {
      key: s,
      onClick: () => toggleWatch(s),
      title: t.notifyHint,
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: '8px 14px',
        borderRadius: 'var(--radius-pill)',
        fontSize: 13,
        fontWeight: 600,
        fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)',
        cursor: 'pointer',
        border: '1px dashed ' + (on ? 'var(--gold-dark)' : 'var(--line)'),
        background: on ? 'var(--gold-tint)' : 'transparent',
        color: on ? 'var(--gold-dark)' : 'var(--text-faint)'
      }
    }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "bell",
      size: 13
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        textDecoration: on ? 'none' : 'line-through',
        opacity: on ? 1 : .8
      }
    }, s, " ", t.pm), on && /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 10,
        fontWeight: 700
      }
    }, "\u2713"));
  })), Object.values(watching).some(Boolean) && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      marginTop: 14,
      fontSize: 12,
      color: 'var(--gold-dark)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "bell",
    size: 14
  }), t.notifyHint)), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '14px 20px',
      borderTop: '1px solid var(--line)',
      background: 'var(--surface-page)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Button, {
    style: {
      width: '100%'
    },
    onClick: () => onConfirm && onConfirm({
      venue: v,
      party,
      time: time + ' ' + t.pm,
      day: t.days[day].join(' ')
    })
  }, t.confirm, " ", party, " ", t.at, " ", time, " ", t.pm), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)',
      textAlign: 'center',
      marginTop: 10
    }
  }, t.free)));
}
function Label({
  children,
  ar
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      fontWeight: 700,
      letterSpacing: ar ? '0' : '.14em',
      textTransform: ar ? 'none' : 'uppercase',
      color: 'var(--text-faint)',
      marginBottom: 10
    }
  }, children);
}
Object.assign(__ds_scope, { BookingFlowScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/BookingFlowScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/ConfirmationScreen.jsx
try { (() => {
const IMG = id => 'https://images.unsplash.com/photo-' + id + '?w=900&q=80&auto=format&fit=crop';
const T = {
  en: {
    over: 'Booking confirmed',
    msg: v => 'We told ' + v.name + " you're coming.",
    date: 'Date',
    time: 'Time',
    guests: 'Guests',
    table: 'Table',
    ref: 'Confirmation',
    cal: 'Add to calendar',
    share: 'Invite friends',
    done: 'Done',
    bookings: 'My bookings',
    city: 'Cairo'
  },
  ar: {
    over: 'تم تأكيد الحجز',
    msg: v => 'بلّغنا ' + v.name + ' إنك جاي.',
    date: 'التاريخ',
    time: 'الوقت',
    guests: 'الأفراد',
    table: 'الطاولة',
    ref: 'رقم الحجز',
    cal: 'أضف للتقويم',
    share: 'اعزم أصحابك',
    done: 'تمام',
    bookings: 'حجوزاتي',
    city: 'القاهرة'
  }
};
function ConfirmationScreen({
  booking = {},
  onDone,
  onBookings,
  lang = 'en'
}) {
  const ar = lang === 'ar';
  const t = T[lang] || T.en;
  const L = x => x && typeof x === 'object' ? ar ? x.ar : x.en : x;
  const dv = {
    en: 'Layali Lounge',
    ar: 'ليالي لاونج'
  };
  const b = {
    venue: {
      name: dv,
      image: IMG('1414235077428-338989a2e8c0'),
      neighbourhood: {
        en: 'Zamalek',
        ar: 'الزمالك'
      }
    },
    party: 2,
    time: ar ? '9:00 م' : '9:00 PM',
    day: ar ? 'الأربع 21' : 'Wed 21',
    table: 'T4',
    ref: 'SAH-4821',
    ...booking
  };
  const vname = L(b.venue.name);
  const cell = (label, value) => /*#__PURE__*/React.createElement("div", {
    key: label,
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10,
      letterSpacing: '.1em',
      textTransform: 'uppercase',
      color: 'var(--text-faint)',
      marginBottom: 3
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      fontWeight: 600,
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)'
    }
  }, value));
  return /*#__PURE__*/React.createElement("div", {
    dir: ar ? 'rtl' : 'ltr',
    style: {
      height: '100%',
      display: 'flex',
      flexDirection: 'column',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)',
      padding: '0 20px 28px',
      position: 'relative',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("style", null, `@keyframes cfRise{0%{opacity:0;transform:translateY(18px)}100%{opacity:1;transform:none}}@keyframes cfSpark{0%{opacity:0;transform:scale(.4) rotate(-30deg)}70%{transform:scale(1.12) rotate(4deg)}100%{opacity:1;transform:none}}`), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      animation: 'cfRise .5s cubic-bezier(.2,.7,.3,1) both'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 44,
      height: 44,
      borderRadius: '50%',
      border: '1.5px solid var(--gold)',
      color: 'var(--gold)',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      animation: 'cfSpark .55s .1s cubic-bezier(.34,1.5,.5,1) both'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "spark",
    size: 20
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      letterSpacing: '.18em',
      textTransform: 'uppercase',
      color: 'var(--gold-dark)',
      fontWeight: 600,
      marginTop: 12
    }
  }, t.over), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      color: 'var(--text-soft)',
      marginTop: 6
    }
  }, t.msg({
    name: vname
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 22,
      position: 'relative',
      animation: 'cfRise .55s .12s cubic-bezier(.2,.7,.3,1) both'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--surface-card)',
      border: '1px solid var(--line)',
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
      textAlign: ar ? 'right' : 'left'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Photo, {
    image: b.venue.image,
    height: 128,
    gradientOverlay: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      insetInlineStart: 16,
      bottom: 12,
      insetInlineEnd: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 21,
      fontWeight: 600,
      color: '#FDFBF7',
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, vname), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'rgba(253,251,247,.85)'
    }
  }, L(b.venue.neighbourhood), " \xB7 ", t.city))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 12,
      padding: '16px 16px 14px'
    }
  }, cell(t.date, b.day), cell(t.time, b.time), cell(t.guests, b.party), cell(t.table, b.table)), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      height: 1,
      margin: '0 2px',
      borderTop: '1px dashed var(--line)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: -7,
      insetInlineStart: -9,
      width: 14,
      height: 14,
      borderRadius: '50%',
      background: 'var(--surface-page)',
      border: '1px solid var(--line)'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: -7,
      insetInlineEnd: -9,
      width: 14,
      height: 14,
      borderRadius: '50%',
      background: 'var(--surface-page)',
      border: '1px solid var(--line)'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '12px 16px 14px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    "aria-hidden": "true",
    style: {
      position: 'absolute',
      inset: 0,
      backgroundImage: __ds_scope.mashrabiyaUrl('currentColor', 34),
      opacity: .04,
      pointerEvents: 'none'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10,
      letterSpacing: '.1em',
      textTransform: 'uppercase',
      color: 'var(--text-faint)'
    }
  }, t.ref), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 13,
      fontWeight: 600,
      letterSpacing: '.06em',
      marginTop: 2
    }
  }, b.ref)), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "lantern",
    size: 20,
    style: {
      color: 'var(--gold)',
      position: 'relative'
    }
  }))))), /*#__PURE__*/React.createElement("div", {
    style: {
      animation: 'cfRise .55s .22s cubic-bezier(.2,.7,.3,1) both'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 12,
      marginBottom: 12
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "secondary",
    style: {
      flex: 1
    },
    icon: /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "calendar-plus",
      size: 16
    })
  }, t.cal), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "secondary",
    style: {
      flex: 1
    },
    icon: /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "share",
      size: 16
    })
  }, t.share)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "ghost",
    style: {
      flex: 1
    },
    onClick: onDone
  }, t.done), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    style: {
      flex: 1
    },
    onClick: onBookings
  }, t.bookings))));
}
Object.assign(__ds_scope, { ConfirmationScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/ConfirmationScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/DiscoverScreen.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const IMG = id => 'https://images.unsplash.com/photo-' + id + '?w=900&q=80&auto=format&fit=crop';
const T = {
  en: {
    eve: 'Good evening, Nour',
    loc: 'Zamalek, Cairo',
    avail: 'Available tonight',
    all: 'See all',
    coll: 'Collections',
    browse: 'Browse',
    iftar: 'Iftar tables, sorted',
    iftarSub: 'Break your fast somewhere memorable',
    places: 'places',
    ramadan: 'Ramadan',
    events: 'Tonight in Cairo',
    rate: 'How was Zooba?',
    rateSub: 'Friday · table for 2 · tap to rate',
    offer: '20% off before 7:30'
  },
  ar: {
    eve: 'مساء الخير يا نور',
    loc: 'الزمالك، القاهرة',
    avail: 'متاح الليلة',
    all: 'الكل',
    coll: 'مجموعات',
    browse: 'تصفّح',
    iftar: 'موائد الإفطار، جاهزة',
    iftarSub: 'افطر في مكان يستاهل',
    places: 'مكان',
    ramadan: 'رمضان',
    events: 'الليلة في القاهرة',
    rate: 'إزاي كانت زوبا؟',
    rateSub: 'الجمعة · طاولة لـ 2 · اضغط للتقييم',
    offer: 'خصم 20٪ قبل 7:30'
  }
};
const tonight = [{
  name: {
    en: 'Layali Lounge',
    ar: 'ليالي لاونج'
  },
  rating: '4.8',
  reviews: 312,
  cuisine: {
    en: 'Levantine',
    ar: 'شامي'
  },
  price: '$$$',
  neighbourhood: {
    en: 'Zamalek',
    ar: 'الزمالك'
  },
  image: IMG('1414235077428-338989a2e8c0'),
  featured: true,
  at: '9:00'
}, {
  name: {
    en: 'Sequoia',
    ar: 'سيكويا'
  },
  rating: '4.6',
  reviews: 540,
  cuisine: {
    en: 'Mediterranean',
    ar: 'متوسطي'
  },
  price: '$$$',
  neighbourhood: {
    en: 'Zamalek',
    ar: 'الزمالك'
  },
  image: IMG('1466978913421-dad2ebd01d17'),
  at: '8:30'
}, {
  name: {
    en: 'Zooba',
    ar: 'زوبا'
  },
  rating: '4.7',
  reviews: 1203,
  cuisine: {
    en: 'Egyptian',
    ar: 'مصري'
  },
  price: '$$',
  neighbourhood: {
    en: 'Downtown',
    ar: 'وسط البلد'
  },
  image: IMG('1555939594-58d7cb561ad1'),
  at: '7:45'
}];
const collections = [{
  t: {
    en: 'Rooftops with a view',
    ar: 'رووف بإطلالة'
  },
  n: 12,
  image: IMG('1600891964092-4316c288032e')
}, {
  t: {
    en: 'Late-night kitchens',
    ar: 'مطابخ لوقت متأخر'
  },
  n: 8,
  image: IMG('1517248135467-4c7edcad34c4')
}, {
  t: {
    en: 'Nile-side terraces',
    ar: 'تراسات على النيل'
  },
  n: 15,
  image: IMG('1470337458703-46ad1756a187')
}];
const events = [{
  t: {
    en: 'Live oud · Layali Lounge',
    ar: 'عود حي · ليالي لاونج'
  },
  when: {
    en: '10 PM · no cover',
    ar: '10 م · بدون رسوم'
  },
  image: IMG('1511671782779-c97d3d27a1d4')
}, {
  t: {
    en: 'Omakase night · Kazoku',
    ar: 'ليلة أوماكاسي · كازوكو'
  },
  when: {
    en: 'Ticketed · EGP 1,800',
    ar: 'بتذكرة · 1,800 ج.م'
  },
  image: IMG('1579027989536-b7b1f875659b'),
  ticketed: true
}, {
  t: {
    en: 'Suhoor on the terrace · Sequoia',
    ar: 'سحور على التراس · سيكويا'
  },
  when: {
    en: 'From 1 AM',
    ar: 'من 1 ص'
  },
  image: IMG('1470337458703-46ad1756a187')
}];
function DiscoverScreen({
  onVenue,
  onOccasion,
  onSave,
  saved = {},
  lang = 'en'
}) {
  const ar = lang === 'ar';
  const t = T[lang] || T.en;
  const L = x => ar ? x.ar : x.en;
  const scrollRef = React.useRef(null);
  const drag = React.useRef({
    on: false,
    y0: 0
  });
  const [pull, setPull] = React.useState(0); // 0..1 of threshold
  const [refreshing, setRefreshing] = React.useState(false);
  const TH = 90;
  const onDown = e => {
    if (scrollRef.current.scrollTop <= 0) {
      drag.current = {
        on: true,
        y0: e.clientY
      };
    }
  };
  const onMove = e => {
    if (!drag.current.on || refreshing) return;
    const d = e.clientY - drag.current.y0;
    if (d > 0 && scrollRef.current.scrollTop <= 0) {
      setPull(Math.min(1, d / TH));
      e.preventDefault();
    }
  };
  const onUp = () => {
    if (!drag.current.on) return;
    drag.current.on = false;
    if (pull >= 1 && !refreshing) {
      setRefreshing(true);
      setTimeout(() => {
        setRefreshing(false);
        setPull(0);
      }, 1300);
    } else setPull(0);
  };
  const [rated, setRated] = React.useState(0);
  const availTxt = v => ar ? '2 · الليلة · ' + v.at + ' م' : '2 · Tonight · ' + v.at + ' PM';
  const vprops = v => ({
    name: L(v.name),
    cuisine: L(v.cuisine),
    neighbourhood: L(v.neighbourhood),
    rating: v.rating,
    reviews: v.reviews,
    price: v.price,
    image: v.image,
    featured: v.featured,
    availability: availTxt(v)
  });
  return /*#__PURE__*/React.createElement("div", {
    dir: ar ? 'rtl' : 'ltr',
    style: {
      height: '100%',
      position: 'relative',
      overflow: 'hidden',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)'
    }
  }, /*#__PURE__*/React.createElement("style", null, `@keyframes sahraLanternSwing{0%,100%{transform:rotate(-7deg)}50%{transform:rotate(7deg)}}`), /*#__PURE__*/React.createElement("div", {
    "aria-hidden": "true",
    style: {
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      height: 64,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 4,
      pointerEvents: 'none',
      transform: 'translateY(' + ((refreshing ? 1 : pull) * 64 - 64) + 'px)',
      opacity: refreshing ? 1 : pull,
      transition: drag.current.on ? 'none' : 'transform .25s ease,opacity .25s ease'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: pull >= 1 || refreshing ? 'var(--gold)' : 'var(--text-faint)',
      display: 'flex',
      transform: refreshing ? 'none' : 'scale(' + (0.6 + 0.4 * pull) + ')',
      animation: refreshing ? 'sahraLanternSwing .9s ease-in-out infinite' : 'none',
      transformOrigin: '50% 0'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "lantern",
    size: 24
  }))), /*#__PURE__*/React.createElement("div", {
    ref: scrollRef,
    onPointerDown: onDown,
    onPointerMove: onMove,
    onPointerUp: onUp,
    onPointerCancel: onUp,
    style: {
      height: '100%',
      overflowY: 'auto',
      touchAction: 'pan-y',
      transform: 'translateY(' + (refreshing ? 1 : pull) * 54 + 'px)',
      transition: drag.current.on ? 'none' : 'transform .25s ease'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '22px 20px 0',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)'
    }
  }, t.eve), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 22,
      fontWeight: 600,
      letterSpacing: ar ? '0' : '-.01em',
      display: 'flex',
      alignItems: 'center',
      gap: 6
    }
  }, t.loc, " ", /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-down",
    size: 18,
    style: {
      color: 'var(--gold)'
    }
  }))), /*#__PURE__*/React.createElement(__ds_scope.Avatar, {
    name: "Nour Hassan",
    src: IMG('1544005313-94ddf0286df2'),
    size: 40
  })), /*#__PURE__*/React.createElement("div", {
    onClick: onOccasion,
    style: {
      margin: '18px 20px 0',
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
      position: 'relative',
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Photo, {
    image: IMG('1528702748617-c64d49f918af'),
    height: 104,
    gradientOverlay: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      padding: '16px 18px',
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'flex-end'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    variant: "gold",
    style: {
      alignSelf: 'flex-start',
      marginBottom: 6
    }
  }, t.ramadan), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 20,
      fontWeight: 600,
      letterSpacing: ar ? '0' : '-.01em',
      color: '#FDFBF7'
    }
  }, t.iftar), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'rgba(253,251,247,.85)'
    }
  }, t.iftarSub, " ", ar ? '←' : '→'))), /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '14px 20px 0',
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      background: 'var(--surface-card)',
      border: '1px solid var(--line)',
      borderRadius: 'var(--radius-lg)',
      padding: '12px 14px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 600
    }
  }, t.rate), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      color: 'var(--text-faint)',
      marginTop: 2
    }
  }, t.rateSub)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 4
    }
  }, [1, 2, 3, 4, 5].map(i => /*#__PURE__*/React.createElement("button", {
    key: i,
    onClick: () => setRated(i),
    "aria-label": 'rate ' + i,
    style: {
      background: 'none',
      border: 'none',
      padding: 2,
      cursor: 'pointer',
      color: i <= rated ? 'var(--gold)' : 'var(--text-faint)',
      display: 'flex'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "star",
    size: 18,
    style: i <= rated ? {
      fill: 'currentColor'
    } : {}
  }))))), /*#__PURE__*/React.createElement(SectionTitle, {
    title: t.avail,
    action: t.all,
    ar: ar
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14,
      overflowX: 'auto',
      padding: '0 20px 4px'
    }
  }, refreshing ? [1, 2, 3].map(i => /*#__PURE__*/React.createElement(__ds_scope.SkeletonCard, {
    key: i,
    style: {
      flex: '0 0 auto',
      width: 244
    }
  })) : tonight.map(v => /*#__PURE__*/React.createElement(__ds_scope.RestaurantCard, _extends({
    key: v.name.en
  }, vprops(v), {
    width: 244,
    imageHeight: 140,
    saved: !!saved[v.name.en],
    onSave: () => onSave && onSave(v.name.en),
    onClick: () => onVenue && onVenue(v),
    style: {
      flex: '0 0 auto'
    }
  })))), /*#__PURE__*/React.createElement(SectionTitle, {
    title: t.events,
    ar: ar
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 12,
      overflowX: 'auto',
      padding: '0 20px 4px'
    }
  }, events.map(e => /*#__PURE__*/React.createElement("div", {
    key: e.t.en,
    onClick: () => onVenue && onVenue(tonight[0]),
    style: {
      flex: '0 0 auto',
      width: 200,
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
      position: 'relative',
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Photo, {
    image: e.image,
    height: 120,
    gradientOverlay: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      padding: '12px 14px',
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'flex-end'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 600,
      color: '#FDFBF7',
      lineHeight: 1.3
    }
  }, L(e.t)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      color: 'rgba(253,251,247,.85)',
      marginTop: 3,
      display: 'flex',
      alignItems: 'center',
      gap: 5
    }
  }, e.ticketed && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "ticket",
    size: 12
  }), L(e.when)))))), /*#__PURE__*/React.createElement(SectionTitle, {
    title: t.coll,
    action: t.browse,
    ar: ar
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 12,
      padding: '0 20px 24px'
    }
  }, collections.map(c => /*#__PURE__*/React.createElement("div", {
    key: c.t.en,
    onClick: () => onVenue && onVenue(tonight[0]),
    style: {
      position: 'relative',
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Photo, {
    image: c.image,
    height: 92,
    gradientOverlay: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      padding: '0 18px',
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 19,
      fontWeight: 600,
      letterSpacing: ar ? '0' : '-.01em',
      color: '#FDFBF7'
    }
  }, L(c.t)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'rgba(253,251,247,.8)'
    }
  }, c.n, " ", t.places)))))));
}
function SectionTitle({
  title,
  action,
  ar
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      justifyContent: 'space-between',
      padding: '22px 20px 12px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 22,
      fontWeight: 600,
      letterSpacing: ar ? '0' : '-.01em',
      color: 'var(--text-body)'
    }
  }, title), action && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      fontWeight: 600,
      color: 'var(--gold-dark)',
      cursor: 'pointer'
    }
  }, action));
}
Object.assign(__ds_scope, { DiscoverScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/DiscoverScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/MyBookingsScreen.jsx
try { (() => {
const IMG = id => 'https://images.unsplash.com/photo-' + id + '?w=900&q=80&auto=format&fit=crop';
const T = {
  en: {
    title: 'My bookings',
    tabs: ['Upcoming', 'Past'],
    confirmed: 'Confirmed',
    tonight: 'Tonight',
    waitlist: 'Waitlist',
    guests: 'guests',
    watching: 'Watching for a table',
    watchHint: "We'll ping you the moment one frees up",
    trail: n => 'Your dining trail · ' + n + ' evenings out'
  },
  ar: {
    title: 'حجوزاتي',
    tabs: ['القادمة', 'السابقة'],
    confirmed: 'مؤكّد',
    tonight: 'الليلة',
    waitlist: 'قائمة انتظار',
    guests: 'أفراد',
    watching: 'بنراقب طاولة',
    watchHint: 'هنبلّغك أول ما تفضى واحدة',
    trail: n => 'رحلتك · ' + n + ' سهرات'
  }
};
const upcoming = [{
  name: {
    en: 'Layali Lounge',
    ar: 'ليالي لاونج'
  },
  image: IMG('1414235077428-338989a2e8c0'),
  when: {
    en: 'Tonight · 9:00 PM',
    ar: 'الليلة · 9:00 م'
  },
  party: 2,
  status: 'confirmed',
  tonight: true
}, {
  name: {
    en: 'Sequoia',
    ar: 'سيكويا'
  },
  image: IMG('1466978913421-dad2ebd01d17'),
  when: {
    en: 'Sat 24 · 8:30 PM',
    ar: 'السبت 24 · 8:30 م'
  },
  party: 4,
  status: 'waitlist'
}];
const past = {
  en: [{
    name: 'Zooba',
    date: 'Fri 16 Feb',
    note: 'Table for 2'
  }, {
    name: 'Kazoku',
    date: 'Sat 3 Feb',
    note: 'Omakase · 4 guests'
  }, {
    name: 'Sachi',
    date: 'Thu 25 Jan',
    note: 'Table for 2'
  }, {
    name: 'Khan El Khalili',
    date: 'Ramadan · 12 Jan',
    note: 'Iftar · 6 guests'
  }],
  ar: [{
    name: 'زوبا',
    date: 'الجمعة 16 فبراير',
    note: 'طاولة لـ 2'
  }, {
    name: 'كازوكو',
    date: 'السبت 3 فبراير',
    note: 'أوماكاسي · 4 أفراد'
  }, {
    name: 'ساتشي',
    date: 'الخميس 25 يناير',
    note: 'طاولة لـ 2'
  }, {
    name: 'خان الخليلي',
    date: 'رمضان · 12 يناير',
    note: 'إفطار · 6 أفراد'
  }]
};
function MyBookingsScreen({
  onVenue,
  onDiscover,
  lang = 'en'
}) {
  const ar = lang === 'ar';
  const t = T[lang] || T.en;
  const L = x => ar ? x.ar : x.en;
  const [tab, setTab] = React.useState('upcoming');
  const pastList = ar ? past.ar : past.en;
  return /*#__PURE__*/React.createElement("div", {
    dir: ar ? 'rtl' : 'ltr',
    style: {
      height: '100%',
      display: 'flex',
      flexDirection: 'column',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '22px 20px 6px',
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 28,
      fontWeight: 600,
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, t.title), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 24,
      padding: '8px 20px 0',
      borderBottom: '1px solid var(--line)'
    }
  }, [['upcoming', t.tabs[0]], ['past', t.tabs[1]]].map(([id, l]) => /*#__PURE__*/React.createElement("button", {
    key: id,
    onClick: () => setTab(id),
    style: {
      background: 'none',
      border: 'none',
      cursor: 'pointer',
      padding: '0 0 12px',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)',
      fontSize: 14,
      fontWeight: 700,
      color: tab === id ? 'var(--text-body)' : 'var(--text-faint)',
      borderBottom: tab === id ? '2px solid var(--terracotta)' : '2px solid transparent'
    }
  }, l))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: 'auto',
      padding: '16px 20px'
    }
  }, tab === 'upcoming' ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      border: '1px dashed var(--gold-dark)',
      borderRadius: 'var(--radius-lg)',
      padding: '12px 14px',
      background: 'var(--gold-tint)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--gold-dark)',
      display: 'flex'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "bell",
    size: 18
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      fontWeight: 700,
      color: 'var(--gold-dark)'
    }
  }, t.watching, " \xB7 ", ar ? 'كازوكو' : 'Kazoku', " \xB7 ", ar ? 'الجمعة 23 · 8:30 م' : 'Fri 23 · 8:30 PM'), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      color: 'var(--text-faint)',
      marginTop: 2
    }
  }, t.watchHint))), upcoming.map(b => /*#__PURE__*/React.createElement("div", {
    key: b.name.en,
    onClick: () => onVenue && onVenue(b),
    style: {
      display: 'flex',
      gap: 14,
      background: 'var(--surface-card)',
      border: '1px solid ' + (b.tonight ? 'rgba(224,169,109,.5)' : 'var(--line)'),
      borderRadius: 'var(--radius-lg)',
      padding: 12,
      cursor: 'pointer',
      boxShadow: b.tonight ? '0 0 24px rgba(224,169,109,.16)' : 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 64
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Photo, {
    image: b.image,
    height: 64,
    radius: 12
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'flex-start'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 17,
      fontWeight: 600,
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, L(b.name)), b.status === 'waitlist' ? /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    variant: "warning"
  }, t.waitlist) : /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    variant: b.tonight ? 'gold' : 'success'
  }, b.tonight ? t.tonight : t.confirmed)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--text-soft)',
      marginTop: 6,
      display: 'flex',
      alignItems: 'center',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: b.tonight ? 'lantern' : 'calendar',
    size: 14,
    style: {
      color: 'var(--gold)'
    }
  }), L(b.when)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--text-faint)',
      marginTop: 3,
      display: 'flex',
      alignItems: 'center',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "users",
    size: 14
  }), b.party, " ", t.guests))))) : /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)',
      marginBottom: 18
    }
  }, t.trail(pastList.length)), /*#__PURE__*/React.createElement(__ds_scope.DiningTrail, {
    visits: pastList
  }))));
}
Object.assign(__ds_scope, { MyBookingsScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/MyBookingsScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/OccasionScreen.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const IMG = id => 'https://images.unsplash.com/photo-' + id + '?w=900&q=80&auto=format&fit=crop';
const T = {
  en: {
    badge: 'Ramadan 1447',
    title: 'Iftar, sorted',
    sub: 'Break your fast somewhere memorable.',
    intro: 'Sunset is at 6:04 PM tonight. These tables hold your iftar seating and serve the moment the cannon sounds.',
    section: 'Iftar tables tonight',
    avail: 'Iftar · 6:10 PM'
  },
  ar: {
    badge: 'رمضان 1447',
    title: 'الإفطار، جاهز',
    sub: 'افطر في مكان يستاهل.',
    intro: 'المغرب الليلة الساعة 6:04 م. الموائد دي بتحجزلك مكان للإفطار وبتقدّم أول ما يضرب المدفع.',
    section: 'موائد الإفطار الليلة',
    avail: 'إفطار · 6:10 م'
  }
};
const iftar = [{
  name: {
    en: 'Layali Lounge',
    ar: 'ليالي لاونج'
  },
  rating: '4.8',
  reviews: 312,
  cuisine: {
    en: 'Levantine',
    ar: 'شامي'
  },
  price: '$$$',
  neighbourhood: {
    en: 'Zamalek',
    ar: 'الزمالك'
  },
  image: IMG('1414235077428-338989a2e8c0')
}, {
  name: {
    en: 'Khan El Khalili',
    ar: 'خان الخليلي'
  },
  rating: '4.6',
  reviews: 702,
  cuisine: {
    en: 'Egyptian',
    ar: 'مصري'
  },
  price: '$$$',
  neighbourhood: {
    en: 'Old Cairo',
    ar: 'مصر القديمة'
  },
  image: IMG('1555939594-58d7cb561ad1')
}];
function OccasionScreen({
  onBack,
  onVenue,
  onSave,
  saved = {},
  lang = 'en'
}) {
  const ar = lang === 'ar';
  const t = T[lang] || T.en;
  const L = x => ar ? x.ar : x.en;
  const vp = v => ({
    name: L(v.name),
    cuisine: L(v.cuisine),
    neighbourhood: L(v.neighbourhood),
    rating: v.rating,
    reviews: v.reviews,
    price: v.price,
    image: v.image,
    availability: t.avail
  });
  return /*#__PURE__*/React.createElement("div", {
    dir: ar ? 'rtl' : 'ltr',
    style: {
      height: '100%',
      overflowY: 'auto',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Photo, {
    image: IMG('1528702748617-c64d49f918af'),
    height: 210,
    gradientOverlay: true
  }), /*#__PURE__*/React.createElement(__ds_scope.Mashrabiya, {
    color: "rgba(224,169,109,0.22)",
    tile: 46,
    style: {
      height: 210
    }
  }), /*#__PURE__*/React.createElement("button", {
    onClick: onBack,
    style: {
      position: 'absolute',
      top: 20,
      insetInlineStart: 20,
      width: 38,
      height: 38,
      borderRadius: '50%',
      border: 'none',
      background: 'rgba(20,12,8,.5)',
      backdropFilter: 'blur(6px)',
      color: '#FDFBF7',
      cursor: 'pointer',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: ar ? 'arrow-right' : 'arrow-left',
    size: 18
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      insetInlineStart: 20,
      insetInlineEnd: 20,
      bottom: 20,
      textAlign: ar ? 'right' : 'left'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    variant: "gold",
    style: {
      marginBottom: 8
    }
  }, t.badge), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 30,
      fontWeight: 600,
      color: '#FDFBF7',
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, t.title), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      color: 'rgba(253,251,247,.85)',
      marginTop: 4
    }
  }, t.sub))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '20px 20px 6px',
      fontSize: 14,
      color: 'var(--text-soft)',
      lineHeight: 1.7,
      textAlign: ar ? 'right' : 'left'
    }
  }, t.intro), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 21,
      fontWeight: 600,
      padding: '16px 20px 12px',
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, t.section), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 14,
      padding: '0 20px 28px'
    }
  }, iftar.map(v => /*#__PURE__*/React.createElement(__ds_scope.RestaurantCard, _extends({
    key: v.name.en
  }, vp(v), {
    width: "100%",
    saved: !!saved[v.name.en],
    onSave: () => onSave && onSave(v.name.en),
    onClick: () => onVenue && onVenue(v)
  })))));
}
Object.assign(__ds_scope, { OccasionScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/OccasionScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Onboarding.jsx
try { (() => {
const COPY = {
  en: [{
    kicker: 'Cairo, tonight',
    title: 'Find the vibe for tonight',
    body: 'Rooftops, late-night kitchens, live oud — the city\u2019s best tables, in one place.'
  }, {
    kicker: 'No phone calls',
    title: 'Book a table in seconds',
    body: 'Real-time availability. Pick a time, we\u2019ll tell them you\u2019re coming.'
  }, {
    kicker: 'For every occasion',
    title: 'From iftar to date night',
    body: 'Curated for Ramadan, birthdays, or just a Tuesday that deserves better.'
  }],
  ar: [{
    kicker: '\u0627\u0644\u0642\u0627\u0647\u0631\u0629\u060c \u0627\u0644\u0644\u064a\u0644\u0629',
    title: '\u0627\u0639\u062b\u0631 \u0639\u0644\u0649 \u0623\u062c\u0648\u0627\u0621 \u0644\u064a\u0644\u062a\u0643',
    body: '\u0631\u0648\u0641 \u062a\u0648\u0628\u060c \u0645\u0637\u0627\u0628\u062e \u062a\u0641\u062a\u062d \u0644\u0648\u0642\u062a \u0645\u062a\u0623\u062e\u0631\u060c \u0648\u0639\u0648\u062f \u062d\u064a \u2014 \u0623\u0641\u0636\u0644 \u0645\u0648\u0627\u0626\u062f \u0627\u0644\u0645\u062f\u064a\u0646\u0629 \u0641\u064a \u0645\u0643\u0627\u0646 \u0648\u0627\u062d\u062f.'
  }, {
    kicker: '\u0645\u0646 \u063a\u064a\u0631 \u0645\u0643\u0627\u0644\u0645\u0627\u062a',
    title: '\u0627\u062d\u062c\u0632 \u0637\u0627\u0648\u0644\u062a\u0643 \u0641\u064a \u062b\u0648\u0627\u0646\u064d',
    body: '\u062a\u0648\u0627\u0641\u0631 \u0644\u062d\u0638\u064a. \u0627\u062e\u062a\u0631 \u0627\u0644\u0648\u0642\u062a\u060c \u0648\u0625\u062d\u0646\u0627 \u0646\u0628\u0644\u0651\u063a\u0647\u0645 \u0625\u0646\u0643 \u062c\u0627\u064a.'
  }, {
    kicker: '\u0644\u0643\u0644 \u0645\u0646\u0627\u0633\u0628\u0629',
    title: '\u0645\u0646 \u0627\u0644\u0625\u0641\u0637\u0627\u0631 \u0644\u0639\u0634\u0627\u0621 \u0631\u0648\u0645\u0627\u0646\u0633\u064a',
    body: '\u0645\u062e\u062a\u0627\u0631\u0629 \u0644\u0631\u0645\u0636\u0627\u0646\u060c \u0623\u0639\u064a\u0627\u062f \u0627\u0644\u0645\u064a\u0644\u0627\u062f\u060c \u0623\u0648 \u062d\u062a\u0649 \u064a\u0648\u0645 \u062a\u0644\u0627\u062a \u064a\u0633\u062a\u0627\u0647\u0644 \u0623\u062d\u0633\u0646.'
  }]
};
const UI = {
  en: {
    next: 'Next',
    start: 'Get started',
    have: 'Already with us?',
    signin: 'Sign in'
  },
  ar: {
    next: '\u0627\u0644\u062a\u0627\u0644\u064a',
    start: '\u0627\u0628\u062f\u0623',
    have: '\u0639\u0646\u062f\u0643 \u062d\u0633\u0627\u0628\u061f',
    signin: '\u0633\u062c\u0651\u0644 \u062f\u062e\u0648\u0644'
  }
};
function Onboarding({
  onStart,
  onSignIn,
  lang = 'en',
  dark = true,
  logoSrc
}) {
  const src = logoSrc || '../../assets/logo.png'; // hero is always dark — cream mark always
  const [i, setI] = React.useState(0);
  const ar = lang === 'ar';
  const slides = COPY[lang] || COPY.en;
  const s = slides[i];
  const u = UI[lang] || UI.en;
  // Content sits in a self-contained rounded card (photo on top) — reads well in BOTH themes,
  // unlike a scrim gradient which washed out in light mode. Card follows surface tokens.
  return /*#__PURE__*/React.createElement("div", {
    className: dark ? 'theme-night' : '',
    dir: ar ? 'rtl' : 'ltr',
    style: {
      height: '100%',
      position: 'relative',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)',
      background: 'var(--surface-page)',
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      flex: 1,
      minHeight: 0
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Photo, {
    height: "100%",
    style: {
      position: 'absolute',
      inset: 0
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 24,
      insetInlineStart: 24
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: src,
    alt: "SAHRA",
    style: {
      width: 42,
      filter: 'drop-shadow(0 2px 8px rgba(0,0,0,.4))'
    }
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--surface-card)',
      borderRadius: '24px 24px 0 0',
      marginTop: -28,
      position: 'relative',
      padding: '28px 26px 32px',
      textAlign: ar ? 'right' : 'left',
      boxShadow: '0 -12px 30px rgba(120,72,40,.12)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      fontWeight: 700,
      letterSpacing: ar ? '0' : '.18em',
      textTransform: 'uppercase',
      color: 'var(--terracotta)'
    }
  }, s.kicker), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-display)',
      fontSize: ar ? 26 : 32,
      fontWeight: ar ? 700 : 600,
      lineHeight: ar ? 1.4 : 1.15,
      margin: '8px 0 10px',
      color: 'var(--text-body)',
      textWrap: 'pretty',
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, s.title), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      lineHeight: 1.7,
      color: 'var(--text-soft)'
    }
  }, s.body), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6,
      margin: '20px 0'
    }
  }, slides.map((_, k) => /*#__PURE__*/React.createElement("span", {
    key: k,
    onClick: () => setI(k),
    style: {
      width: k === i ? 22 : 7,
      height: 7,
      borderRadius: 4,
      background: k === i ? 'var(--terracotta)' : 'var(--line)',
      cursor: 'pointer',
      transition: 'width .2s'
    }
  }))), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    style: {
      width: '100%'
    },
    onClick: () => i < slides.length - 1 ? setI(i + 1) : onStart && onStart()
  }, i < slides.length - 1 ? u.next : u.start), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      marginTop: 16,
      fontSize: 14,
      color: 'var(--text-soft)'
    }
  }, u.have, " ", /*#__PURE__*/React.createElement("span", {
    onClick: onSignIn,
    style: {
      color: 'var(--terracotta)',
      fontWeight: 600,
      cursor: 'pointer'
    }
  }, u.signin))));
}
Object.assign(__ds_scope, { Onboarding });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Onboarding.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/ProfileScreen.jsx
try { (() => {
const IMG = id => 'https://images.unsplash.com/photo-' + id + '?w=900&q=80&auto=format&fit=crop';
const T = {
  en: {
    since: 'Member since 2024 · Cairo',
    stats: [['12', 'Bookings'], ['34', 'Saved'], ['4.9', 'Rating']],
    rows: [['calendar-check', 'My bookings'], ['heart', 'Saved places'], ['users', 'Invite friends'], ['bell', 'Notifications'], ['credit-card', 'Payment methods'], ['globe', 'Language · English'], ['circle-help', 'Help & support']],
    out: 'Sign out',
    mybk: 'My bookings',
    pts: '240 points',
    ptsTo: '60 to your free dessert at Zööba'
  },
  ar: {
    since: 'عضو منذ 2024 · القاهرة',
    stats: [['12', 'حجوزات'], ['34', 'محفوظة'], ['4.9', 'تقييم']],
    rows: [['calendar-check', 'حجوزاتي'], ['heart', 'الأماكن المحفوظة'], ['users', 'ادعُ أصدقاءك'], ['bell', 'الإشعارات'], ['credit-card', 'طرق الدفع'], ['globe', 'اللغة · العربية'], ['circle-help', 'المساعدة والدعم']],
    out: 'تسجيل الخروج',
    mybk: 'حجوزاتي',
    pts: '240 نقطة',
    ptsTo: 'باقي 60 نقطة على الحلو المجاني في زوبا'
  }
};
function ProfileScreen({
  onBookings,
  lang = 'en'
}) {
  const ar = lang === 'ar';
  const t = T[lang] || T.en;
  return /*#__PURE__*/React.createElement("div", {
    dir: ar ? 'rtl' : 'ltr',
    style: {
      height: '100%',
      overflowY: 'auto',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '30px 20px 22px',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      textAlign: 'center',
      borderBottom: '1px solid var(--line)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Avatar, {
    name: "Nour Hassan",
    src: IMG('1544005313-94ddf0286df2'),
    size: 76
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 23,
      fontWeight: 600,
      marginTop: 12,
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, ar ? 'نور حسن' : 'Nour Hassan'), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--text-faint)'
    }
  }, t.since), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 0,
      marginTop: 18,
      width: '100%'
    }
  }, t.stats.map(([n, l], i) => /*#__PURE__*/React.createElement("div", {
    key: l,
    style: {
      flex: 1,
      borderInlineStart: i ? '1px solid var(--line)' : 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 20,
      fontWeight: 600,
      color: 'var(--gold)'
    }
  }, n), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      color: 'var(--text-faint)'
    }
  }, l))))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '14px 20px 0'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: '13px 16px',
      background: 'var(--surface-card)',
      border: '1px solid var(--line)',
      borderRadius: 12
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--gold-dark)',
      display: 'flex'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "spark",
    size: 20
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 16,
      fontWeight: 600,
      color: 'var(--gold-dark)'
    }
  }, t.pts), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)'
    }
  }, t.ptsTo)), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 4,
      borderRadius: 999,
      background: 'var(--line)',
      marginTop: 8,
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: '80%',
      height: '100%',
      borderRadius: 999,
      background: 'var(--gold)'
    }
  }))))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '8px 8px 20px'
    }
  }, t.rows.map(([ic, l], i) => /*#__PURE__*/React.createElement("button", {
    key: i,
    onClick: i === 0 ? onBookings : undefined,
    style: {
      width: '100%',
      display: 'flex',
      alignItems: 'center',
      gap: 14,
      padding: '15px 14px',
      background: 'none',
      border: 'none',
      borderBottom: '1px solid var(--line)',
      cursor: 'pointer',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)',
      color: 'var(--text-body)',
      textAlign: ar ? 'right' : 'left'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--terracotta)',
      display: 'flex'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: ic,
    size: 19
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      fontSize: 15
    }
  }, l), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: ar ? 'chevron-left' : 'chevron-right',
    size: 17,
    style: {
      color: 'var(--text-faint)'
    }
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '20px 14px 0'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "secondary",
    style: {
      width: '100%'
    }
  }, t.out))));
}
Object.assign(__ds_scope, { ProfileScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/ProfileScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/SavedScreen.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const IMG = id => 'https://images.unsplash.com/photo-' + id + '?w=900&q=80&auto=format&fit=crop';
const T = {
  en: {
    title: 'Saved',
    chips: ['All', 'Date night', 'Rooftops', 'Want to try'],
    avail: 'Tonight'
  },
  ar: {
    title: 'المحفوظة',
    chips: ['الكل', 'عشاء رومانسي', 'رووف', 'ودّي أجرب'],
    avail: 'الليلة'
  }
};
const all = [{
  name: {
    en: 'Kazoku',
    ar: 'كازوكو'
  },
  rating: '4.9',
  reviews: 210,
  cuisine: {
    en: 'Japanese',
    ar: 'ياباني'
  },
  price: '$$$$',
  neighbourhood: {
    en: 'Garden City',
    ar: 'جاردن سيتي'
  },
  image: IMG('1579027989536-b7b1f875659b'),
  at: '10:00'
}, {
  name: {
    en: 'Zooba',
    ar: 'زوبا'
  },
  rating: '4.7',
  reviews: 1203,
  cuisine: {
    en: 'Egyptian',
    ar: 'مصري'
  },
  price: '$$',
  neighbourhood: {
    en: 'Downtown',
    ar: 'وسط البلد'
  },
  image: IMG('1555939594-58d7cb561ad1'),
  at: '7:45'
}, {
  name: {
    en: 'Sachi',
    ar: 'ساتشي'
  },
  rating: '4.5',
  reviews: 880,
  cuisine: {
    en: 'Fusion',
    ar: 'فيوژن'
  },
  price: '$$$',
  neighbourhood: {
    en: 'New Cairo',
    ar: 'القاهرة الجديدة'
  },
  image: IMG('1517248135467-4c7edcad34c4')
}];
function SavedScreen({
  onVenue,
  saved = {},
  onSave,
  onDiscover,
  lang = 'en'
}) {
  const ar = lang === 'ar';
  const t = T[lang] || T.en;
  const L = x => ar ? x.ar : x.en;
  const vp = v => ({
    name: L(v.name),
    cuisine: L(v.cuisine),
    neighbourhood: L(v.neighbourhood),
    rating: v.rating,
    reviews: v.reviews,
    price: v.price,
    image: v.image,
    availability: v.at ? t.avail + ' · ' + v.at + (ar ? ' م' : ' PM') : undefined
  });
  return /*#__PURE__*/React.createElement("div", {
    dir: ar ? 'rtl' : 'ltr',
    style: {
      height: '100%',
      overflowY: 'auto',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '22px 20px 4px',
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 28,
      fontWeight: 600,
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, t.title), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      padding: '12px 20px',
      overflowX: 'auto'
    }
  }, t.chips.map((c, i) => /*#__PURE__*/React.createElement(__ds_scope.Chip, {
    key: i,
    active: i === 0,
    style: {
      flex: '0 0 auto'
    }
  }, c))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 14,
      padding: '8px 20px 24px'
    }
  }, all.map(v => /*#__PURE__*/React.createElement(__ds_scope.RestaurantCard, _extends({
    key: v.name.en
  }, vp(v), {
    width: "100%",
    imageHeight: 110,
    saved: true,
    onSave: () => onSave && onSave(v.name.en),
    onClick: () => onVenue && onVenue(v)
  })))));
}
Object.assign(__ds_scope, { SavedScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/SavedScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/SearchScreen.jsx
try { (() => {
const IMG = id => 'https://images.unsplash.com/photo-' + id + '?w=900&q=80&auto=format&fit=crop';
const T = {
  en: {
    chips: ['Tonight', 'Collections', 'Lists', 'Events'],
    open: '11 places open tonight',
    next: 'Next',
    search: 'Search',
    city: 'CAIRO',
    expand: 'Expand map',
    collapse: 'Collapse'
  },
  ar: {
    chips: ['الليلة', 'مجموعات', 'قوائم', 'فعاليات'],
    open: '11 مكان مفتوح الليلة',
    next: 'القادم',
    search: 'ابحث',
    city: 'القاهرة',
    expand: 'كبّر الخريطة',
    collapse: 'صغّر'
  }
};
const results = [{
  name: {
    en: 'Layali Lounge',
    ar: 'ليالي لاونج'
  },
  rating: '4.8',
  reviews: 312,
  cuisine: {
    en: 'Levantine',
    ar: 'شامي'
  },
  price: '$$$',
  image: IMG('1414235077428-338989a2e8c0'),
  time: '9:00',
  pos: [30.0622, 31.2185]
}, {
  name: {
    en: 'Sequoia',
    ar: 'سيكويا'
  },
  rating: '4.6',
  reviews: 540,
  cuisine: {
    en: 'Mediterranean',
    ar: 'متوسطي'
  },
  price: '$$$',
  image: IMG('1466978913421-dad2ebd01d17'),
  time: '8:30',
  pos: [30.0742, 31.2249]
}, {
  name: {
    en: 'Kazoku',
    ar: 'كازوكو'
  },
  rating: '4.9',
  reviews: 210,
  cuisine: {
    en: 'Japanese',
    ar: 'ياباني'
  },
  price: '$$$$',
  image: IMG('1579027989536-b7b1f875659b'),
  time: '10:00',
  pos: [30.0585, 31.2228]
}];
function SearchScreen({
  onVenue,
  lang = 'en'
}) {
  const ar = lang === 'ar';
  const t = T[lang] || T.en;
  const L = x => ar ? x.ar : x.en;
  const [chip, setChip] = React.useState(0);
  const [big, setBig] = React.useState(false);
  const pins = results.map(v => ({
    name: L(v.name),
    pos: v.pos,
    time: v.time,
    venue: v
  }));
  const vp = v => ({
    name: L(v.name),
    cuisine: L(v.cuisine),
    rating: v.rating,
    reviews: v.reviews,
    price: v.price,
    image: v.image
  });
  return /*#__PURE__*/React.createElement("div", {
    dir: ar ? 'rtl' : 'ltr',
    style: {
      height: '100%',
      display: 'flex',
      flexDirection: 'column',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '22px 20px 12px',
      display: 'flex',
      flexDirection: 'column',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.SearchBar, {
    placeholder: t.search,
    location: t.city
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      overflowX: 'auto'
    }
  }, t.chips.map((c, i) => /*#__PURE__*/React.createElement(__ds_scope.Chip, {
    key: i,
    active: chip === i,
    onClick: () => setChip(i),
    style: {
      flex: '0 0 auto'
    }
  }, c)))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: 'auto',
      padding: '0 20px 20px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.MapCard, {
    height: big ? 400 : 170,
    city: t.city,
    pins: pins,
    onPin: p => onVenue && onVenue(p.venue)
  }), /*#__PURE__*/React.createElement("button", {
    onClick: () => setBig(!big),
    style: {
      position: 'absolute',
      insetInlineEnd: 10,
      top: 10,
      zIndex: 3,
      width: 30,
      height: 30,
      borderRadius: '50%',
      border: '1px solid var(--line)',
      background: 'var(--surface-card)',
      color: 'var(--text-soft)',
      cursor: 'pointer',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    },
    "aria-label": big ? t.collapse : t.expand
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: big ? 'chevron-up' : 'compass',
    size: 15
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--text-faint)',
      margin: '16px 0 10px'
    }
  }, t.open), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 12
    }
  }, results.map(v => {
    const p = vp(v);
    return /*#__PURE__*/React.createElement("div", {
      key: v.name.en,
      onClick: () => onVenue && onVenue(v),
      style: {
        display: 'flex',
        gap: 12,
        background: 'var(--surface-card)',
        border: '1px solid var(--line)',
        borderRadius: 'var(--radius-lg)',
        padding: 10,
        cursor: 'pointer'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        width: 76,
        flexShrink: 0
      }
    }, /*#__PURE__*/React.createElement(__ds_scope.Photo, {
      image: p.image,
      height: 76,
      radius: 12
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        minWidth: 0
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
        fontSize: 17,
        fontWeight: 600,
        letterSpacing: ar ? '0' : '-.01em'
      }
    }, p.name), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "heart",
      size: 16,
      style: {
        color: 'var(--text-faint)'
      }
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        marginTop: 3
      }
    }, /*#__PURE__*/React.createElement(__ds_scope.RatingStars, {
      rating: p.rating,
      reviews: p.reviews,
      size: 12
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 12,
        color: 'var(--text-faint)'
      }
    }, " \xB7 ", p.cuisine, " \xB7 ", p.price)), /*#__PURE__*/React.createElement("div", {
      style: {
        marginTop: 8
      }
    }, /*#__PURE__*/React.createElement(__ds_scope.Badge, {
      variant: "featured",
      style: {
        fontSize: 10
      }
    }, t.next, ": ", v.time, " ", ar ? 'م' : 'PM'))));
  }))));
}
Object.assign(__ds_scope, { SearchScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/SearchScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/SignInScreen.jsx
try { (() => {
const T = {
  en: {
    l1: 'Find',
    l2: 'the vibe',
    l3: 'for tonight',
    signin: 'SIGN IN',
    signup: 'SIGN UP',
    phone: 'Phone number',
    phoneP: '+20 100 000 0000',
    pass: 'Password',
    name: 'Name',
    nameP: 'Your name',
    cont: 'Continue',
    forgot: 'Forgot password?',
    fb: 'Facebook',
    g: 'Google',
    or: 'or'
  },
  ar: {
    l1: '\u0627\u0639\u062b\u0631 \u0639\u0644\u0649',
    l2: '\u0627\u0644\u0623\u062c\u0648\u0627\u0621',
    l3: '\u0627\u0644\u0645\u0646\u0627\u0633\u0628\u0629 \u0644\u0644\u064a\u0644\u062a\u0643',
    signin: '\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644',
    signup: '\u062d\u0633\u0627\u0628 \u062c\u062f\u064a\u062f',
    phone: '\u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062a\u0641',
    phoneP: '+20 100 000 0000',
    pass: '\u0643\u0644\u0645\u0629 \u0627\u0644\u0633\u0631',
    name: '\u0627\u0644\u0627\u0633\u0645',
    nameP: '\u0627\u0633\u0645\u0643',
    cont: '\u0645\u062a\u0627\u0628\u0639\u0629',
    forgot: '\u0646\u0633\u064a\u062a \u0643\u0644\u0645\u0629 \u0627\u0644\u0633\u0631\u061f',
    fb: '\u0641\u064a\u0633\u0628\u0648\u0643',
    g: '\u062c\u0648\u062c\u0644',
    or: '\u0623\u0648'
  }
};
function SignInScreen({
  onContinue,
  onClose,
  lang = 'en',
  dark = true,
  logoSrc
}) {
  const src = logoSrc || (dark ? '../../assets/logo.png' : '../../assets/logo-terracotta.png');
  const [tab, setTab] = React.useState('in');
  const ar = lang === 'ar';
  const t = T[lang] || T.en;
  const social = {
    flex: 1,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    padding: '12px 0',
    borderRadius: 'var(--radius-md)',
    border: '1px solid var(--line)',
    background: 'var(--surface-card)',
    color: 'var(--text-body)',
    fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)',
    fontSize: 13,
    fontWeight: 600,
    cursor: 'pointer'
  };
  return /*#__PURE__*/React.createElement("div", {
    dir: ar ? 'rtl' : 'ltr',
    style: {
      height: '100%',
      position: 'relative',
      display: 'flex',
      flexDirection: 'column',
      padding: '20px 24px 32px',
      boxSizing: 'border-box',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)',
      textAlign: ar ? 'right' : 'left',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Mashrabiya, {
    color: "var(--text-body)",
    opacity: dark ? 0.05 : 0.035,
    tile: 46,
    fade: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: src,
    alt: "SAHRA",
    style: {
      width: 34
    }
  }), /*#__PURE__*/React.createElement("button", {
    onClick: onClose,
    style: {
      background: 'none',
      border: 'none',
      color: 'var(--text-faint)',
      cursor: 'pointer',
      display: 'flex',
      padding: 4
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "x",
    size: 20
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-display)',
      fontSize: ar ? 30 : 38,
      lineHeight: ar ? 1.4 : 1.12,
      marginTop: 26,
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontWeight: ar ? 600 : 400,
      color: 'var(--text-body)'
    }
  }, t.l1), /*#__PURE__*/React.createElement("div", {
    style: {
      fontWeight: 700,
      color: 'var(--terracotta)',
      fontStyle: ar ? 'normal' : 'italic'
    }
  }, t.l2), /*#__PURE__*/React.createElement("div", {
    style: {
      fontWeight: 600,
      color: 'var(--text-body)'
    }
  }, t.l3)), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'flex',
      gap: 24,
      marginTop: 26
    }
  }, [['in', t.signin], ['up', t.signup]].map(([id, l]) => /*#__PURE__*/React.createElement("button", {
    key: id,
    onClick: () => setTab(id),
    style: {
      background: 'none',
      border: 'none',
      cursor: 'pointer',
      padding: '0 0 8px',
      color: tab === id ? 'var(--text-body)' : 'var(--text-faint)',
      borderBottom: tab === id ? '2px solid var(--terracotta)' : '2px solid transparent',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)',
      fontSize: 13,
      fontWeight: 700,
      letterSpacing: ar ? '0' : '.1em'
    }
  }, l))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'flex',
      gap: 12,
      marginTop: 22
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: social
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "facebook",
    size: 17,
    style: {
      color: '#1877F2'
    }
  }), t.fb), /*#__PURE__*/React.createElement("button", {
    style: social
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontWeight: 800,
      color: '#EA4335'
    }
  }, "G"), t.g)), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      margin: '20px 0'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      height: 1,
      background: 'var(--line)'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)'
    }
  }, t.or), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      height: 1,
      background: 'var(--line)'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'flex',
      flexDirection: 'column',
      gap: 18
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Input, {
    variant: "line",
    label: t.phone,
    placeholder: t.phoneP
  }), /*#__PURE__*/React.createElement(__ds_scope.Input, {
    variant: "line",
    label: t.pass,
    type: "password",
    defaultValue: "password"
  }), tab === 'up' && /*#__PURE__*/React.createElement(__ds_scope.Input, {
    variant: "line",
    label: t.name,
    placeholder: t.nameP
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    onClick: onContinue,
    style: {
      position: 'relative',
      width: '100%',
      letterSpacing: ar ? '0' : '.1em',
      fontSize: 14
    }
  }, t.cont), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      textAlign: 'center',
      marginTop: 16,
      fontSize: 13,
      fontStyle: ar ? 'normal' : 'italic',
      color: 'var(--text-soft)'
    }
  }, t.forgot));
}
Object.assign(__ds_scope, { SignInScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/SignInScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/SplashScreen.jsx
try { (() => {
// App-launch splash. Theme-aware: night surface + cream mark in dark mode, warm cream surface +
// terracotta mark in light mode. Motion: crisp mark settle → wordmark tracks in → gold hairline
// draws → quick fade handoff. No blur/glow shadows.
function SplashScreen({
  onDone,
  lang = 'en',
  dark = true,
  logoSrc,
  duration = 2000
}) {
  const ar = lang === 'ar';
  const src = logoSrc || (dark ? '../../assets/logo.png' : '../../assets/logo-terracotta.png');
  const [leaving, setLeaving] = React.useState(false);
  React.useEffect(() => {
    const t1 = setTimeout(() => setLeaving(true), duration);
    const t2 = setTimeout(() => onDone && onDone(), duration + 380);
    return () => {
      clearTimeout(t1);
      clearTimeout(t2);
    };
  }, [duration, onDone]);
  return /*#__PURE__*/React.createElement("div", {
    className: dark ? 'theme-night' : '',
    style: {
      position: 'absolute',
      inset: 0,
      background: dark ? 'var(--night)' : 'var(--cream)',
      overflow: 'hidden',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      opacity: leaving ? 0 : 1,
      transition: 'opacity .38s ease',
      zIndex: 50
    }
  }, /*#__PURE__*/React.createElement("style", null, `
      @keyframes sahraMark{0%{opacity:0;transform:translateY(8px) scale(.92)}100%{opacity:1;transform:none}}
      @keyframes sahraWord{0%{opacity:0;letter-spacing:.55em}100%{opacity:1;letter-spacing:.32em}}
      @keyframes sahraLine{0%{transform:scaleX(0)}100%{transform:scaleX(1)}}
      @keyframes sahraLattice{0%{opacity:0}100%{opacity:1}}
      @keyframes sahraSub{0%{opacity:0;transform:translateY(6px)}100%{opacity:1;transform:none}}
    `), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      animation: 'sahraLattice 1.6s .6s ease both'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Mashrabiya, {
    color: dark ? 'var(--gold)' : 'var(--terracotta)',
    opacity: dark ? 0.05 : 0.04,
    tile: 52,
    fade: true
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 20
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: src,
    alt: "SAHRA",
    style: {
      width: 92,
      animation: 'sahraMark .7s .1s cubic-bezier(.2,.7,.2,1) both'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 600,
      fontSize: 20,
      letterSpacing: '.32em',
      color: dark ? 'var(--night-text)' : 'var(--terracotta-dark)',
      animation: 'sahraWord .8s .55s cubic-bezier(.2,.7,.2,1) both',
      paddingInlineStart: '.32em'
    }
  }, "SAHRA"), /*#__PURE__*/React.createElement("div", {
    "aria-hidden": "true",
    style: {
      width: 44,
      height: 2,
      background: dark ? 'var(--gold)' : 'var(--gold-dark)',
      transformOrigin: 'center',
      animation: 'sahraLine .5s .95s cubic-bezier(.2,.7,.2,1) both'
    }
  }), ar && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-arabic-display)',
      fontSize: 14,
      color: dark ? 'var(--night-text-faint)' : 'var(--text-faint)',
      animation: 'sahraSub .5s 1.15s ease both'
    }
  }, "\u0633\u0647\u0631\u0629")));
}
Object.assign(__ds_scope, { SplashScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/SplashScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/VenueDetailScreen.jsx
try { (() => {
const IMG = id => 'https://images.unsplash.com/photo-' + id + '?w=900&q=80&auto=format&fit=crop';
const T = {
  en: {
    featured: 'Featured tonight',
    friends: 'Nour & 11 friends have been here',
    desc: 'A Nile-side terrace built for long evenings — mezze, charcoal grills and live oud after ten. Come for the sunset call to prayer, stay for the last table standing.',
    info: [['clock', 'Open tonight', '6:00 PM – 2:00 AM'], ['map-pin', '26th of July St, Zamalek', 'Get directions'], ['phone', '+20 2 2735 0000', 'Call venue']],
    from: 'From',
    free: 'Free to book',
    book: 'Book a table',
    menu: 'From the menu',
    fullMenu: 'Full menu',
    offer: 'Sunset offer — 20% off tables before 7:30 PM',
    egp: 'EGP'
  },
  ar: {
    featured: 'مميز الليلة',
    friends: 'نور و١١ صديق جرّبوا المكان',
    desc: 'تراس على النيل متصمم للسهرات الطويلة — مقبّلات، مشويات على الفحم، وعود حي بعد العاشرة. تعالى لأذان المغرب، واقعد لآخر طاولة.',
    info: [['clock', 'مفتوح الليلة', '6:00 م – 2:00 ص'], ['map-pin', 'شارع 26 يوليو، الزمالك', 'الاتجاهات'], ['phone', '+20 2 2735 0000', 'اتصل بالمكان']],
    from: 'يبدأ من',
    free: 'الحجز مجاني',
    book: 'احجز طاولة',
    menu: 'من المنيو',
    fullMenu: 'المنيو كامل',
    offer: 'عرض الغروب — خصم 20٪ على الطاولات قبل 7:30 م',
    egp: 'ج.م'
  }
};
const menu = {
  en: [['Charred halloumi & date honey', 'Mezze', '320'], ['Mixed grill for two', 'Charcoal', '980'], ['Freekeh-stuffed pigeon', 'Signature', '540'], ['Umm Ali, pistachio crust', 'Dessert', '210']],
  ar: [['حلومي مشوي بعسل البلح', 'مقبّلات', '320'], ['مشوي مشكل لفردين', 'فحم', '980'], ['حمام محشي فريك', 'أطباق مميزة', '540'], ['أم علي بالفستق', 'حلو', '210']]
};
const friends = [{
  name: 'Nour H',
  src: IMG('1544005313-94ddf0286df2')
}, {
  name: 'Omar A',
  src: IMG('1507003211169-0a1dd7228f2d')
}, {
  name: 'Laila F',
  src: IMG('1438761681033-6461ffad8d80')
}, {
  name: 'K M'
}, {
  name: 'S T'
}];
const gallery = ['1414235077428-338989a2e8c0', '1600891964092-4316c288032e', '1470337458703-46ad1756a187', '1517248135467-4c7edcad34c4'];
function VenueDetailScreen({
  venue = {},
  onBack,
  onBook,
  onSave,
  saved,
  lang = 'en'
}) {
  const ar = lang === 'ar';
  const t = T[lang] || T.en;
  const L = x => x && typeof x === 'object' ? ar ? x.ar : x.en : x;
  const v = {
    name: {
      en: 'Layali Lounge',
      ar: 'ليالي لاونج'
    },
    rating: '4.8',
    reviews: 312,
    cuisine: {
      en: 'Levantine',
      ar: 'شامي'
    },
    price: '$$$',
    neighbourhood: {
      en: 'Zamalek',
      ar: 'الزمالك'
    },
    image: IMG('1414235077428-338989a2e8c0'),
    ...venue
  };
  return /*#__PURE__*/React.createElement("div", {
    dir: ar ? 'rtl' : 'ltr',
    style: {
      height: '100%',
      display: 'flex',
      flexDirection: 'column',
      fontFamily: ar ? 'var(--font-arabic)' : 'var(--font-latin)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: 'auto'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Photo, {
    image: v.image,
    height: 280,
    gradientOverlay: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 20,
      left: 20,
      right: 20,
      display: 'flex',
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement(IconBtn, {
    name: ar ? 'arrow-right' : 'arrow-left',
    onClick: onBack
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(IconBtn, {
    name: "share"
  }), /*#__PURE__*/React.createElement(IconBtn, {
    name: "heart",
    active: saved,
    onClick: onSave
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 20,
      right: 20,
      bottom: 18,
      textAlign: ar ? 'right' : 'left'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    variant: "featured",
    style: {
      marginBottom: 8
    }
  }, t.featured), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 30,
      fontWeight: 600,
      color: '#FDFBF7',
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, L(v.name)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      marginTop: 4,
      color: 'rgba(253,251,247,.9)',
      fontSize: 13,
      flexWrap: 'wrap'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.RatingStars, {
    rating: v.rating,
    reviews: v.reviews
  }), " \xB7 ", L(v.cuisine), " \xB7 ", v.price, " \xB7 ", L(v.neighbourhood)))), /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '14px 20px 0',
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      padding: '11px 14px',
      borderRadius: 'var(--radius-md)',
      background: 'var(--gold-tint)',
      border: '1px solid rgba(196,138,75,.35)',
      color: 'var(--gold-dark)',
      fontSize: 13,
      fontWeight: 600
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "tag",
    size: 16
  }), t.offer), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '18px 20px 12px',
      textAlign: ar ? 'right' : 'left'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.AvatarStack, {
    people: friends,
    label: t.friends
  }), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 14,
      lineHeight: 1.7,
      color: 'var(--text-soft)',
      marginTop: 16
    }
  }, t.desc)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      overflowX: 'auto',
      padding: '4px 20px 8px'
    }
  }, gallery.map(g => /*#__PURE__*/React.createElement("div", {
    key: g,
    style: {
      flex: '0 0 auto',
      width: 120
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Photo, {
    image: IMG(g),
    height: 90,
    radius: 12
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '16px 20px 4px',
      textAlign: ar ? 'right' : 'left'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: ar ? 'var(--font-arabic-display)' : 'var(--font-display)',
      fontSize: 19,
      fontWeight: 600,
      letterSpacing: ar ? '0' : '-.01em'
    }
  }, t.menu), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      fontWeight: 600,
      color: 'var(--gold-dark)',
      cursor: 'pointer'
    }
  }, t.fullMenu)), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 6
    }
  }, (ar ? menu.ar : menu.en).map(([dish, cat, price]) => /*#__PURE__*/React.createElement("div", {
    key: dish,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: '12px 0',
      borderBottom: '1px solid var(--line)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 600
    }
  }, dish), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      color: 'var(--text-faint)',
      letterSpacing: ar ? '0' : '.06em',
      textTransform: ar ? 'none' : 'uppercase',
      marginTop: 2
    }
  }, cat)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 700,
      color: 'var(--text-soft)',
      whiteSpace: 'nowrap'
    }
  }, price, " ", /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      fontWeight: 500,
      color: 'var(--text-faint)'
    }
  }, t.egp)))))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '12px 20px 0'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.MapCard, {
    height: 140,
    city: ar ? 'الزمالك' : 'ZAMALEK',
    pins: [{
      name: L(v.name),
      pos: [30.0622, 31.2185],
      time: ar ? '9:00' : '9:00'
    }],
    center: [30.0622, 31.2185],
    zoom: 15,
    interactive: false
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '12px 20px 20px',
      display: 'flex',
      flexDirection: 'column',
      gap: 2
    }
  }, t.info.map(([ic, a, b]) => /*#__PURE__*/React.createElement("div", {
    key: a,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: '14px 0',
      borderBottom: '1px solid var(--line)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--terracotta)',
      display: 'flex'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: ic,
    size: 18
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 600
    }
  }, a), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 600,
      color: 'var(--gold-dark)'
    }
  }, b)))))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '14px 20px',
      borderTop: '1px solid var(--line)',
      background: 'var(--surface-page)',
      display: 'flex',
      alignItems: 'center',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)'
    }
  }, t.from), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      fontWeight: 700
    }
  }, t.free)), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    style: {
      flex: 1
    },
    onClick: onBook
  }, t.book)));
}
function IconBtn({
  name,
  active,
  onClick
}) {
  return /*#__PURE__*/React.createElement("button", {
    onClick: onClick,
    style: {
      width: 38,
      height: 38,
      borderRadius: '50%',
      border: 'none',
      background: 'rgba(20,12,8,.5)',
      backdropFilter: 'blur(6px)',
      color: active ? 'var(--gold)' : '#FDFBF7',
      cursor: 'pointer',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: name,
    size: 18
  }));
}
Object.assign(__ds_scope, { VenueDetailScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/VenueDetailScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/operator/OperatorDashboard.jsx
try { (() => {
const IMG = id => 'https://images.unsplash.com/photo-' + id + '?w=200&q=80&auto=format&fit=crop';
const BOOKINGS = [{
  time: '7:30',
  name: 'Mariam El-Sayed',
  party: 2,
  table: 'T4',
  status: 'seated',
  note: 'Anniversary — window table requested',
  src: IMG('1438761681033-6461ffad8d80')
}, {
  time: '8:00',
  name: 'Omar Adel',
  party: 4,
  table: 'T9',
  status: 'confirmed',
  note: 'Regular · prefers the terrace',
  src: IMG('1507003211169-0a1dd7228f2d')
}, {
  time: '8:30',
  name: 'Nour Hassan',
  party: 2,
  table: 'T2',
  status: 'confirmed',
  note: '',
  src: IMG('1544005313-94ddf0286df2')
}, {
  time: '9:00',
  name: 'Khaled Mostafa',
  party: 6,
  table: 'T12',
  status: 'late',
  note: 'Called — 15 min behind',
  src: null
}, {
  time: '9:15',
  name: 'Salma Tarek',
  party: 3,
  table: 'T6',
  status: 'confirmed',
  note: 'Vegetarian menu flagged',
  src: null
}, {
  time: '10:00',
  name: 'Youssef Nabil',
  party: 2,
  table: 'T3',
  status: 'pending',
  note: '',
  src: null
}];
const TABLES = [['T1', 0], ['T2', 2], ['T3', 0], ['T4', 1], ['T5', 0], ['T6', 0], ['T7', 1], ['T8', 0], ['T9', 2], ['T10', 1], ['T11', 0], ['T12', 0]]; // 0 free, 1 occupied, 2 reserved-next
const STATUS = {
  seated: ['Seated', 'featured'],
  confirmed: ['Confirmed', 'default'],
  late: ['Running late', 'warning'],
  pending: ['Pending', 'muted']
};
function OperatorDashboard({
  dark = false,
  venue = 'Layali Lounge'
}) {
  const [filter, setFilter] = React.useState('all');
  const rows = BOOKINGS.filter(b => filter === 'all' || b.status === filter);
  const box = {
    background: 'var(--surface-card)',
    border: '1px solid var(--line)',
    borderRadius: 'var(--radius-lg)'
  };
  return /*#__PURE__*/React.createElement("div", {
    className: dark ? 'theme-night' : '',
    style: {
      width: '100%',
      height: '100%',
      display: 'flex',
      background: 'var(--surface-page)',
      color: 'var(--text-body)',
      fontFamily: 'var(--font-latin)',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("aside", {
    style: {
      width: 200,
      borderInlineEnd: '1px solid var(--line)',
      padding: '22px 14px',
      display: 'flex',
      flexDirection: 'column',
      gap: 4,
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Mashrabiya, {
    color: "var(--text-body)",
    opacity: 0.03,
    tile: 44,
    fade: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      padding: '0 8px 18px'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: dark ? '../../assets/logo.png' : '../../assets/logo-terracotta.png',
    alt: "SAHRA",
    style: {
      width: 26
    }
  }), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 600,
      fontSize: 14,
      letterSpacing: '.14em'
    }
  }, "SAHRA"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10,
      color: 'var(--text-faint)',
      letterSpacing: '.08em'
    }
  }, "FOR RESTAURANTS"))), [['calendar', 'Tonight', true], ['map-pin', 'Floor plan', false], ['users', 'Guests', false], ['star', 'Reviews', false], ['mezze', 'Menu', false]].map(([ic, l, on]) => /*#__PURE__*/React.createElement("div", {
    key: l,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      padding: '9px 10px',
      borderRadius: 'var(--radius-md)',
      fontSize: 13,
      fontWeight: on ? 600 : 500,
      color: on ? 'var(--accent)' : 'var(--text-soft)',
      background: on ? 'var(--terracotta-tint)' : 'transparent',
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: ic,
    size: 16
  }), l))), /*#__PURE__*/React.createElement("main", {
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("header", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '18px 24px',
      borderBottom: '1px solid var(--line)'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 21,
      fontWeight: 600,
      letterSpacing: '-.01em'
    }
  }, venue, " \u2014 tonight"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)'
    }
  }, "Wednesday 21 \xB7 service 6:00 PM \u2013 2:00 AM")), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "sm",
    icon: /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "plus",
      size: 14
    })
  }, "Walk-in")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 12,
      padding: '16px 24px 0'
    }
  }, [['Covers booked', '46'], ['Occupancy', '72%'], ['Seated now', '18'], ['No-shows', '1']].map(([l, v]) => /*#__PURE__*/React.createElement("div", {
    key: l,
    style: {
      ...box,
      flex: 1,
      padding: '12px 16px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      color: 'var(--text-faint)',
      letterSpacing: '.06em',
      textTransform: 'uppercase'
    }
  }, l), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 24,
      fontWeight: 600,
      marginTop: 2
    }
  }, v)))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      padding: '14px 24px 10px'
    }
  }, [['all', 'All'], ['confirmed', 'Confirmed'], ['seated', 'Seated'], ['late', 'Late'], ['pending', 'Pending']].map(([id, l]) => /*#__PURE__*/React.createElement(__ds_scope.Chip, {
    key: id,
    selected: filter === id,
    onClick: () => setFilter(id)
  }, l))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: 'auto',
      padding: '0 24px 20px',
      display: 'flex',
      flexDirection: 'column',
      gap: 8
    }
  }, rows.map(b => /*#__PURE__*/React.createElement("div", {
    key: b.name,
    style: {
      ...box,
      display: 'flex',
      alignItems: 'center',
      gap: 14,
      padding: '12px 16px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 16,
      fontWeight: 600,
      width: 44
    }
  }, b.time), /*#__PURE__*/React.createElement(__ds_scope.Avatar, {
    name: b.name,
    src: b.src,
    size: 36
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 600
    }
  }, b.name), b.note && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)',
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, b.note)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      fontSize: 13,
      color: 'var(--text-soft)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "users",
    size: 14
  }), b.party), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--text-soft)',
      width: 34
    }
  }, b.table), /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    variant: STATUS[b.status][1]
  }, STATUS[b.status][0]))))), /*#__PURE__*/React.createElement("aside", {
    style: {
      width: 230,
      borderInlineStart: '1px solid var(--line)',
      padding: '20px 18px',
      display: 'flex',
      flexDirection: 'column',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      fontWeight: 600,
      letterSpacing: '.08em',
      textTransform: 'uppercase',
      color: 'var(--text-faint)'
    }
  }, "Floor \xB7 main room"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(3,1fr)',
      gap: 10
    }
  }, TABLES.map(([t, s]) => /*#__PURE__*/React.createElement("div", {
    key: t,
    style: {
      aspectRatio: '1',
      borderRadius: 'var(--radius-md)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontSize: 12,
      fontWeight: 600,
      border: '1px solid ' + (s === 1 ? 'var(--terracotta)' : s === 2 ? 'var(--gold-dark)' : 'var(--line)'),
      background: s === 1 ? 'var(--terracotta-tint)' : s === 2 ? 'var(--gold-tint)' : 'var(--surface-card)',
      color: s === 1 ? 'var(--terracotta-dark)' : s === 2 ? 'var(--gold-dark)' : 'var(--text-faint)'
    }
  }, t))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 12,
      fontSize: 11,
      color: 'var(--text-faint)',
      flexWrap: 'wrap'
    }
  }, [['var(--terracotta)', 'Seated'], ['var(--gold-dark)', 'Reserved next'], ['var(--line)', 'Free']].map(([c, l]) => /*#__PURE__*/React.createElement("span", {
    key: l,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 5
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 9,
      height: 9,
      borderRadius: 3,
      border: '1px solid ' + c,
      display: 'inline-block'
    }
  }), l)))));
}
Object.assign(__ds_scope, { OperatorDashboard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/operator/OperatorDashboard.jsx", error: String((e && e.message) || e) }); }

__ds_ns.DiningTrail = __ds_scope.DiningTrail;

__ds_ns.Mashrabiya = __ds_scope.Mashrabiya;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Chip = __ds_scope.Chip;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.Skeleton = __ds_scope.Skeleton;

__ds_ns.SkeletonCard = __ds_scope.SkeletonCard;

__ds_ns.SearchBar = __ds_scope.SearchBar;

__ds_ns.TabBar = __ds_scope.TabBar;

__ds_ns.Avatar = __ds_scope.Avatar;

__ds_ns.AvatarStack = __ds_scope.AvatarStack;

__ds_ns.EmptyState = __ds_scope.EmptyState;

__ds_ns.BookingWidget = __ds_scope.BookingWidget;

__ds_ns.RatingStars = __ds_scope.RatingStars;

__ds_ns.RestaurantCard = __ds_scope.RestaurantCard;

__ds_ns.BookingFlowScreen = __ds_scope.BookingFlowScreen;

__ds_ns.ConfirmationScreen = __ds_scope.ConfirmationScreen;

__ds_ns.DiscoverScreen = __ds_scope.DiscoverScreen;

__ds_ns.MapCard = __ds_scope.MapCard;

__ds_ns.MyBookingsScreen = __ds_scope.MyBookingsScreen;

__ds_ns.OccasionScreen = __ds_scope.OccasionScreen;

__ds_ns.Onboarding = __ds_scope.Onboarding;

__ds_ns.Photo = __ds_scope.Photo;

__ds_ns.ProfileScreen = __ds_scope.ProfileScreen;

__ds_ns.SavedScreen = __ds_scope.SavedScreen;

__ds_ns.SearchScreen = __ds_scope.SearchScreen;

__ds_ns.SignInScreen = __ds_scope.SignInScreen;

__ds_ns.SplashScreen = __ds_scope.SplashScreen;

__ds_ns.VenueDetailScreen = __ds_scope.VenueDetailScreen;

__ds_ns.OperatorDashboard = __ds_scope.OperatorDashboard;

})();
