Signature Cairo mashrabiya lattice as a full-bleed background texture. Parent must be `position:relative`. Use low opacity behind empty states, dividers, occasion headers, image placeholders.
```jsx
<div style={{position:'relative'}}><Mashrabiya color="rgba(221,95,53,0.10)" tile={40} fade/>...</div>
```
`mashrabiyaUrl(color,tile)` returns the CSS `url(...)` for direct use as a backgroundImage.