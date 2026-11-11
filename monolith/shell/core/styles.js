.pragma library
// The styles (Settings → Theme → Style): each is a whole look. Keys:
//   name, desc          what Settings shows
//   matugen             colours from the wallpaper (else its own `colors`, or the colour theme you pick)
//   opaque              false: panels see-through (blur, liquid glass, bubbly)
//   radiusScale         corners × this (with your corner setting); square: no rounding
//   outline [w, w2]     outline width on panels and controls; outlineRole: its colour
//                       (accent, accentSoft, ink = the text colour, text, rule = a faint line)
//   hardShadow          a solid offset shadow of this many px instead of a soft one
//   font                its typeface (used when installed; your own font setting wins)
//   oled                true black backgrounds
//   liquid              liquid glass: clearer panes, a light rim and shine, widgets bend what's behind them
//   colors              its palette (base, mantle, crust, surface0–2, overlay0–2, text, subtext0–1, accents)
// (The looks and palettes are the earlier Monolith's styles.)
var list = [
 {
  "name": "Material",
  "opaque": true,
  "radiusScale": 1.8,
  "font": "Google Sans Flex",
  "matugen": true,
  "pill": true,
  "desc": "Soft, round, your wallpaper's colours",
  "id": "material"
 },
 {
  "name": "Orbit",
  "opaque": true,
  "radiusScale": 1.0,
  "matugen": true,
  "desc": "Tonal layers, hairline edges, floating cards",
  "id": "orbit"
 },
 {
  "name": "Blur",
  "opaque": false,
  "id": "blur",
  "desc": "See-through panels over your wallpaper",
  "matugen": true
 },
 {
  "name": "Liquid glass",
  "opaque": false,
  "id": "liquid",
  "liquid": true,
  "desc": "Clear glass that bends the light at its edges, your wallpaper's colours",
  "matugen": true
 },
 {
  "name": "Minimalist",
  "opaque": true,
  "square": true,
  "outline": [
   2,
   1
  ],
  "font": "JetBrains Mono",
  "desc": "Flat, square, grey outlines",
  "id": "minimalist"
 },
 {
  "name": "Terminal",
  "opaque": true,
  "square": true,
  "outline": [
   1,
   1
  ],
  "outlineRole": "accent",
  "font": "JetBrains Mono",
  "desc": "Phosphor on black, thin accent frames",
  "colors": {
   "base": "#0b0d0b",
   "mantle": "#070907",
   "crust": "#000000",
   "surface0": "#141914",
   "surface1": "#1c241c",
   "surface2": "#2a362a",
   "overlay0": "#3d4d3d",
   "overlay1": "#557055",
   "overlay2": "#6f906f",
   "text": "#c9f5c4",
   "subtext0": "#86b383",
   "subtext1": "#a6d4a2",
   "blue": "#7cf29a",
   "sapphire": "#7cf29a",
   "teal": "#7cf2d6",
   "mauve": "#7cf29a",
   "pink": "#f2c97c",
   "green": "#7cf29a",
   "yellow": "#f2e27c",
   "peach": "#f2b27c",
   "red": "#f27c7c",
   "maroon": "#d46a6a"
  },
  "id": "terminal"
 },
 {
  "name": "Brutal",
  "opaque": true,
  "square": false,
  "radiusScale": 0.5,
  "outline": [
   3,
   2
  ],
  "outlineRole": "ink",
  "hardShadow": 5,
  "font": "Space Grotesk",
  "desc": "Cream, thick ink lines, hard shadows",
  "colors": {
   "base": "#fff4dc",
   "mantle": "#f7e9c6",
   "crust": "#141414",
   "surface0": "#ffe08a",
   "surface1": "#ffd25c",
   "surface2": "#141414",
   "overlay0": "#5a5246",
   "overlay1": "#3d372e",
   "overlay2": "#2a261f",
   "text": "#141414",
   "subtext0": "#3d372e",
   "subtext1": "#2a261f",
   "blue": "#3a7bff",
   "sapphire": "#3a7bff",
   "teal": "#1fb8a6",
   "mauve": "#ff5c3a",
   "pink": "#ff7eb6",
   "green": "#2bb24c",
   "yellow": "#ffd23f",
   "peach": "#ff8a3a",
   "red": "#e5262b",
   "maroon": "#b3191e"
  },
  "id": "brutal"
 },
 {
  "name": "Luxe",
  "opaque": true,
  "radiusScale": 0.6,
  "outline": [
   1,
   1
  ],
  "outlineRole": "accentSoft",
  "font": "SF Pro Display",
  "desc": "Black chassis, ivory ink, gold detail",
  "colors": {
   "base": "#0e0d0c",
   "mantle": "#090807",
   "crust": "#050404",
   "surface0": "#191715",
   "surface1": "#24211d",
   "surface2": "#3a342c",
   "overlay0": "#5b5246",
   "overlay1": "#7a6f60",
   "overlay2": "#9b8e7c",
   "text": "#efe6d4",
   "subtext0": "#b3a892",
   "subtext1": "#d0c5ae",
   "blue": "#c9a96e",
   "sapphire": "#c9a96e",
   "teal": "#a8b89a",
   "mauve": "#c9a96e",
   "pink": "#c98a7a",
   "green": "#a8b89a",
   "yellow": "#d9c08a",
   "peach": "#d4a373",
   "red": "#8e2f2a",
   "maroon": "#6e2420"
  },
  "id": "luxe"
 },
 {
  "name": "Poster",
  "opaque": true,
  "square": true,
  "outline": [
   3,
   2
  ],
  "outlineRole": "text",
  "font": "SF Pro Display",
  "desc": "Carbon plates, signal yellow, bold frames",
  "colors": {
   "base": "#111111",
   "mantle": "#0a0a0a",
   "crust": "#000000",
   "surface0": "#1d1d1d",
   "surface1": "#2a2a2a",
   "surface2": "#3b3b3b",
   "overlay0": "#5c5c5c",
   "overlay1": "#7a7a7a",
   "overlay2": "#9a9a9a",
   "text": "#f5f5f0",
   "subtext0": "#b0b0a8",
   "subtext1": "#d6d6ce",
   "blue": "#ffd400",
   "sapphire": "#ffd400",
   "teal": "#00e0c6",
   "mauve": "#ffd400",
   "pink": "#ff4f8b",
   "green": "#3ddc84",
   "yellow": "#ffd400",
   "peach": "#ff8a00",
   "red": "#ff3b30",
   "maroon": "#c42b22"
  },
  "id": "poster"
 },
 {
  "name": "Bubbly",
  "opaque": false,
  "radiusScale": 2.2,
  "desc": "Extra round, keeps your colours",
  "id": "bubbly",
  "matugen": true
 },
 {
  "name": "Paper",
  "opaque": true,
  "radiusScale": 0.35,
  "outline": [
   1,
   1
  ],
  "outlineRole": "rule",
  "font": "Lora",
  "desc": "Ink on paper, serif type, fine rules",
  "colors": {
   "base": "#f5f2eb",
   "mantle": "#ece7dc",
   "crust": "#f9f7f2",
   "surface0": "#e8e2d4",
   "surface1": "#ddd5c4",
   "surface2": "#c9bfab",
   "overlay0": "#a39a88",
   "overlay1": "#857c6b",
   "overlay2": "#6b6355",
   "text": "#242321",
   "subtext0": "#5e584e",
   "subtext1": "#45403a",
   "blue": "#2f5d8a",
   "sapphire": "#2f5d8a",
   "teal": "#3d7a6e",
   "mauve": "#8a3b2e",
   "pink": "#a85a6e",
   "green": "#4a7a3d",
   "yellow": "#b08a2e",
   "peach": "#b8662e",
   "red": "#a8322e",
   "maroon": "#7a2420"
  },
  "id": "paper"
 },
 {
  "name": "Arcade",
  "opaque": true,
  "square": true,
  "outline": [
   2,
   1
  ],
  "outlineRole": "accent",
  "hardShadow": 4,
  "font": "Bitcount Prop Single",
  "desc": "Pixel type, neon on night blue, glowing drop shadows",
  "colors": {
   "base": "#110f2b",
   "mantle": "#0b0a20",
   "crust": "#060514",
   "surface0": "#1c1a42",
   "surface1": "#29265a",
   "surface2": "#3a3678",
   "overlay0": "#55509a",
   "overlay1": "#726db5",
   "overlay2": "#938fcf",
   "text": "#f4f1ff",
   "subtext0": "#b3aee0",
   "subtext1": "#d3cff2",
   "blue": "#3ad8ff",
   "sapphire": "#3ad8ff",
   "teal": "#3dffd0",
   "mauve": "#ff3df2",
   "pink": "#ff6ec7",
   "green": "#5cff8a",
   "yellow": "#ffe14d",
   "peach": "#ff9e3d",
   "red": "#ff4d6d",
   "maroon": "#d63a57"
  },
  "id": "arcade"
 },
 {
  "name": "OLED",
  "opaque": true,
  "radiusScale": 1.3,
  "font": "Roboto",
  "matugen": true,
  "oled": true,
  "desc": "Pure black, your wallpaper's accents",
  "id": "oled"
 },
 {
  "name": "Mainframe",
  "opaque": true,
  "square": true,
  "outline": [
   1,
   1
  ],
  "outlineRole": "accent",
  "font": "3270 Nerd Font",
  "desc": "Amber CRT, IBM 3270 type",
  "colors": {
   "base": "#0d0a05",
   "mantle": "#090703",
   "crust": "#000000",
   "surface0": "#1a1409",
   "surface1": "#261d0d",
   "surface2": "#3a2c13",
   "overlay0": "#5c4520",
   "overlay1": "#80612d",
   "overlay2": "#a67f3c",
   "text": "#ffb347",
   "subtext0": "#c98a2e",
   "subtext1": "#e69f3a",
   "blue": "#ffb347",
   "sapphire": "#ffc46b",
   "teal": "#ffd28a",
   "mauve": "#ffb347",
   "pink": "#ff9f6b",
   "green": "#d8c05a",
   "yellow": "#ffd24d",
   "peach": "#ff9a3d",
   "red": "#ff5f3d",
   "maroon": "#cc4a2e"
  },
  "id": "mainframe"
 },
 {
  "name": "Sakura",
  "opaque": true,
  "radiusScale": 1.6,
  "pill": true,
  "outline": [
   1,
   1
  ],
  "outlineRole": "rule",
  "font": "Google Sans Flex",
  "desc": "Pastel pink, soft and very round",
  "colors": {
   "base": "#fff5f7",
   "mantle": "#fdecf0",
   "crust": "#ffffff",
   "surface0": "#fbe0e7",
   "surface1": "#f6cfda",
   "surface2": "#eab6c5",
   "overlay0": "#c993a3",
   "overlay1": "#a97585",
   "overlay2": "#8c5b6b",
   "text": "#3d2a31",
   "subtext0": "#7a5562",
   "subtext1": "#5c3f49",
   "blue": "#7d9cd6",
   "sapphire": "#6bb0c9",
   "teal": "#6cbfa8",
   "mauve": "#e2638f",
   "pink": "#ef7fa6",
   "green": "#7dbb7a",
   "yellow": "#e0b04f",
   "peach": "#ef9a6b",
   "red": "#d9546a",
   "maroon": "#b5405a"
  },
  "id": "sakura"
 },
 {
  "name": "Fjord",
  "opaque": true,
  "radiusScale": 1.0,
  "outline": [
   1,
   1
  ],
  "outlineRole": "accentSoft",
  "font": "Roboto",
  "desc": "Arctic blue-grey, frosted accents",
  "colors": {
   "base": "#2e3440",
   "mantle": "#292e39",
   "crust": "#242933",
   "surface0": "#3b4252",
   "surface1": "#434c5e",
   "surface2": "#4c566a",
   "overlay0": "#616e88",
   "overlay1": "#7b88a1",
   "overlay2": "#949fb5",
   "text": "#eceff4",
   "subtext0": "#d8dee9",
   "subtext1": "#e5e9f0",
   "blue": "#81a1c1",
   "sapphire": "#88c0d0",
   "teal": "#8fbcbb",
   "mauve": "#88c0d0",
   "pink": "#b48ead",
   "green": "#a3be8c",
   "yellow": "#ebcb8b",
   "peach": "#d08770",
   "red": "#bf616a",
   "maroon": "#a5545c"
  },
  "id": "fjord"
 },
 {
  "name": "Doodle",
  "opaque": true,
  "radiusScale": 1.3,
  "outline": [
   2,
   1
  ],
  "outlineRole": "ink",
  "hardShadow": 3,
  "font": "ComicShannsMono Nerd Font",
  "desc": "Sketchbook paper, inked lines, marker colours",
  "colors": {
   "base": "#fbfaf4",
   "mantle": "#f3f1e6",
   "crust": "#22201c",
   "surface0": "#ecead9",
   "surface1": "#e0ddc6",
   "surface2": "#c9c5a8",
   "overlay0": "#9a9680",
   "overlay1": "#77745f",
   "overlay2": "#5a5746",
   "text": "#22201c",
   "subtext0": "#5a5746",
   "subtext1": "#3d3b30",
   "blue": "#2f6fdb",
   "sapphire": "#2a8fc4",
   "teal": "#1e9e8a",
   "mauve": "#e0457b",
   "pink": "#f06aa4",
   "green": "#3a9e3a",
   "yellow": "#f2c230",
   "peach": "#f28a30",
   "red": "#e03c3c",
   "maroon": "#b52d2d"
  },
  "id": "doodle"
 },
 {
  "name": "Shadow",
  "opaque": true,
  "radiusScale": 1.6,
  "font": "JetBrains Mono",
  "desc": "Grey cards, monospace type, no colour",
  "colors": {
   "base": "#141415",
   "mantle": "#0f0f10",
   "crust": "#0a0a0b",
   "surface0": "#2a2a2d",
   "surface1": "#36363a",
   "surface2": "#4a4a4f",
   "overlay0": "#5c5c60",
   "overlay1": "#7c7c80",
   "overlay2": "#9c9ca0",
   "text": "#f0f0f0",
   "subtext0": "#a3a3a6",
   "subtext1": "#c6c6c9",
   "blue": "#e8e8e8",
   "sapphire": "#d8d8d8",
   "teal": "#cfcfcf",
   "mauve": "#f0f0f0",
   "pink": "#dcdcdc",
   "green": "#d4d4d4",
   "yellow": "#e4e4e4",
   "peach": "#d0d0d0",
   "red": "#ff8a80",
   "maroon": "#e57373"
  },
  "id": "shadow"
 }
];
