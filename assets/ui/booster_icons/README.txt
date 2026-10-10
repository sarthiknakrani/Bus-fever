BUS FEVER — Clean Booster Icon Pack

Files
- vip_icon.png — orange VIP vehicle with crown; transparent exterior; no blue button or label
- arrange_icon.png — yellow bus with colorful passengers; transparent exterior; no blue button or label
- jumble_icon.png — multicolor ball; transparent exterior; no blue button or label

All PNGs are 512 x 512 RGBA. Illustrations originated from a newly generated visual asset sheet and were isolated as standalone icons; they have been resampled from smaller renderings to 512x512 for convenient use. Evaluate clarity at the actual on-screen size rather than treating 512x512 as native detail.

Intended installation
res://assets/ui/booster_icons/{filename}

Godot integration
- Keep existing glossy blue Button/TextureButton and green plus badge; do not replace entire button image.
- Add one TextureRect visual icon (or equivalent) using these PNG files with mouse_filter = IGNORE.
- Scale to around 65-75% of existing button FACE, maintain aspect ratio, and center.
- Keep exactly ONE label outside each button.
- Keep all existing click signals, actions, existing badge and Level 1/2 shared scene.
- Check import filtering at real rendered dimensions; do not create a nested second button.

These PNGs are icon artworks only. Click behavior comes from Godot UI controls.
