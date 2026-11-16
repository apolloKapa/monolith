.pragma library
// The styles (Settings → Theme → Style): each is a whole look. Keys:
//   name, desc          what Settings shows
//   matugen             colours from the wallpaper (else its own `colors`, or the colour theme you pick)
//   opaque              false: panels see-through (liquid glass, bubbly); blur is a setting for any style
//   radiusScale         corners × this (with your corner setting); square: no rounding
//   outline [w, w2]     outline width on panels and controls; outlineRole: its colour
//                       (accent, accentSoft, ink = the text colour, text, rule = a faint line)
//   hardShadow          a solid offset shadow of this many px instead of a soft one
//   font                its typeface (used when installed; your own font setting wins)
//   oled                true black backgrounds
//   liquid              liquid glass: clearer panes, a light rim and shine, widgets bend what's behind them
//   chamfer             corners cut straight across instead of rounded (Cyberpunk)
//   glitch              things glitch in and the Blackwall takes them out (ui/CyberFx, Cyberpunk)
//   fx, fxIn, fxOut     its own way of drawing things in and out (Theme.fxKind), and how long each takes
//   material            what its panels are made of (ui/MaterialPane): concrete, paper or steel
//   sounds              its own interface sound pack (sounds/<pack>), played instead of yours
//   colors              its palette (base, mantle, crust, surface0–2, overlay0–2, text, subtext0–1, accents)
// A style changes the whole shell, not only its colours (Cyberpunk, Liquid glass and the materials);
// the light ones were removed in 2.9.66, keeping Material (the default), Fjord, Doodle and Terminal.
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
  "name": "Liquid glass",
  "opaque": false,
  "fx": "liquid",
  "fxIn": 560,
  "fxOut": 440,
  "id": "liquid",
  "liquid": true,
  "desc": "Clear glass that bends the light at its edges, your wallpaper's colours",
  "matugen": true
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
  "fx": "terminal",
  "fxIn": 560,
  "fxOut": 400,
  "id": "terminal"
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
  "material": "paper",
  "fx": "paper",
  "fxIn": 560,
  "fxOut": 440,
  "id": "paper"
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
  "fx": "fjord",
  "fxIn": 620,
  "fxOut": 500,
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
  "fx": "doodle",
  "fxIn": 620,
  "fxOut": 460,
  "id": "doodle"
 },
 {
  "name": "Cyberpunk",
  "opaque": true,
  "chamfer": true,
  "glitch": true,
  "radiusScale": 1.5,
  "outline": [
   1,
   1
  ],
  "outlineRole": "accentSoft",
  "font": "Rajdhani",
  "desc": "Neon on black, cut corners; things glitch in and the Blackwall takes them out",
  "colors": {
   "base": "#0a0a0f",
   "mantle": "#07070b",
   "crust": "#030305",
   "surface0": "#12121a",
   "surface1": "#1b1b27",
   "surface2": "#262636",
   "overlay0": "#3a3a52",
   "overlay1": "#55557a",
   "overlay2": "#7a7aa0",
   "text": "#e6fbff",
   "subtext0": "#8aa4b0",
   "subtext1": "#b6c9d2",
   "blue": "#00f0ff",
   "sapphire": "#00b8ff",
   "teal": "#00f0ff",
   "mauve": "#00f0ff",
   "pink": "#ff2a6d",
   "green": "#05ffa1",
   "yellow": "#fcee0a",
   "peach": "#fcee0a",
   "red": "#ff003c",
   "maroon": "#c4002e"
  },
  "id": "cyberpunk"
 },
 {
  "name": "Concrete",
  "fx": "concrete",
  "fxIn": 540,
  "fxOut": 560,
  "id": "concrete",
  "opaque": true,
  "square": true,
  "outline": [
   3,
   2
  ],
  "outlineRole": "ink",
  "hardShadow": 6,
  "font": "Space Grotesk",
  "material": "concrete",
  "desc": "Raw cast concrete, heavy ink lines, hard shadows: brutalist",
  "colors": {
   "base": "#aeada8",
   "mantle": "#a3a29d",
   "crust": "#141413",
   "surface0": "#bab9b4",
   "surface1": "#c6c5c0",
   "surface2": "#1a1a19",
   "overlay0": "#73726e",
   "overlay1": "#53524f",
   "overlay2": "#3b3a38",
   "text": "#121211",
   "subtext0": "#363533",
   "subtext1": "#252423",
   "blue": "#e8501f",
   "sapphire": "#e8501f",
   "teal": "#2d6a6a",
   "mauve": "#e8501f",
   "pink": "#d9452e",
   "green": "#3f7d3a",
   "yellow": "#e0b420",
   "peach": "#e8501f",
   "red": "#c42b1c",
   "maroon": "#9e2416"
  }
 },
 {
  "name": "Industrial",
  "fx": "industrial",
  "fxIn": 560,
  "fxOut": 500,
  "id": "industrial",
  "opaque": true,
  "radiusScale": 0.8,
  "outline": [
   1,
   1
  ],
  "outlineRole": "rule",
  "font": "JetBrains Mono",
  "material": "steel",
  "desc": "Brushed gunmetal, amber accents",
  "colors": {
   "base": "#2e3136",
   "mantle": "#26292d",
   "crust": "#141619",
   "surface0": "#3a3e44",
   "surface1": "#464b52",
   "surface2": "#565c64",
   "overlay0": "#6b727b",
   "overlay1": "#858c95",
   "overlay2": "#a0a7b0",
   "text": "#e9ecef",
   "subtext0": "#a9b0b8",
   "subtext1": "#c6ccd2",
   "blue": "#ffb020",
   "sapphire": "#4ea3d9",
   "teal": "#4fb3a8",
   "mauve": "#ffb020",
   "pink": "#e0607a",
   "green": "#6cc070",
   "yellow": "#ffd24a",
   "peach": "#ffb020",
   "red": "#e5484d",
   "maroon": "#b8373b"
  }
 }
];
