# lib/ui — shared UI foundation (port of React design)
Imports: `import '../ui/tokens.dart'; '../ui/widgets.dart'; '../ui/card_face.dart'; '../utils/lucide_icons.dart';`
Fonts: Plus Jakarta Sans (`T.text`) / JetBrains Mono (`T.mono`). Screen scroll content bottom padding: `T.navBottomPad` (112).

## tokens.dart — `T`
Colors: `bg fg card cyan200/300/400/500/600 indigo500 emerald emerald300/400 red300/400/500 amber300/500 sky slate900`;
`T.white(o)`, `T.blk(o)`, `T.op(color,o)`. Gradients: `glassGradient tintGradient btnLiquidGradient`.
Radii: `rGlass26 rStrong16 rSheet32 rBtn18 rField14 rKey20 rNav34 rNavItem28 rCard22`. Spacing: `s1..s8, screenPad(20), btnH, fieldH, keyH`.
Shadows: `glassShadow strongShadow tintShadow btnShadow lensShadow T.glow(c,blur)`.
Text: `T.text(size,{w,color,height,ls,shadows})`, `T.mono(size,{w,color,height,ls})`, weights `T.w500/600/700/800`, presets `h1 h2 h3 body label caption btn`.

## widgets.dart
- `PressScale({child,onTap,scale=.97})` press animation.
- `Glass({child,kind=GlassKind.glass|strong|tint|pill,radius,padding,margin,width,height,fill,borderRadius,blur=true})` (= .glass/.glass-strong/.glass-tint/.glass-pill; use `radius:` for `!rounded-[..]`).
- `Btn({child,onTap,disabled,variant=BtnVariant.primary|glass|danger,width,padding})`, `Btn.text(label,{onTap,disabled,variant,width})`. Use `width: double.infinity` for w-full.
- `GlassIconBtn({icon,onTap,size=32,iconSize=16,color})`.
- `Field({label,mono,controller,hint,obscure,keyboardType,onChanged,onSubmitted,inputFormatters,maxLength,suffix,enabled,initialValue,textInputAction,focusNode})`.
- `Toggle({on,onChanged,label,hint})`; `Numpad({value,onChanged,max=6})`; `PinDots({n,max=4})`.
- `Badge2(text,{color,textColor,mono,fontSize})`; `SectionHeader(title,{trailing})`; `LinkText(text,onTap:)`.
- `AppBackground({child})` — #0A0E17 + animated aurora orbs; wrap every screen/shell body (no Scaffold bg needed).
- `AppBottomNav({index,onTap,tabs=kNavTabs})` + `AppBottomNav.positioned(index:,onTap:)` (place inside a Stack); `NavTab(label,icon)`.
- `FadeSlideIn({child})` tab-switch entrance (key by tab).
- `showAppSheet<T>(context,{title,child,tall=false})` → Future<T?> (pop with Navigator.pop).
- `showToast(context, message,{duration})` top-center pill.
- `NfcTap({title,apdu,onSuccess,onCancel,doneLabel,successNode})` full-screen; `showNfcTap(context,{title,apdu,doneLabel,successNode})` → Future<bool?> (true=success).

## card_face.dart
- `CardData({id,name,material,network,num,kind('virtual'|'pass'|'bank'),physical,format('qr'|'barcode'),code,bank})`; `kMaterials[name]` (.label/.accent).
- `CardFace({card,holder,tiltX,tiltY,frozen,small})`, `PassFace({card})`, `CardChip()`, `CodeMark({qr,value,dark})`, `cssLinear(deg,colors,stops)`.
- `Card3D({front:(tx,ty)=>Widget, back, flipped, onFlip, onSwipe(±1), flat(x-ray), tapToFlip=false, cardWidth=290, stageHeight=270, cardTop=44})` — pointer tilt, double-tap flip, vertical swipe. Key with `ValueKey(card.id)` to replay entrance. Back face (`Back` in CardsScreen.tsx) is screen-specific.

## React → Flutter mapping
| React | Flutter file to rewrite |
|---|---|
| LandingScreen.tsx + AuthScreen.tsx | lib/screens/auth_screen.dart |
| HomeScreen.tsx | lib/screens/home_screen.dart |
| CardsScreen.tsx + AddCard.tsx | lib/screens/virtual_cards_screen.dart |
| SarEScreen.tsx | lib/screens/sare_screen.dart |
| AnalyticsScreen.tsx | lib/screens/analytics_screen.dart |
| ProfileScreen.tsx | lib/screens/profile_screen.dart |
| components/SecurityScreen.tsx | lib/screens/security_info_screen.dart |
| Overlays.tsx | nfc_flow_screen.dart / nfc_unlock_screen.dart / widgets/jcop_tap_overlay.dart |
| App.tsx shell | lib/screens/main_shell.dart |
