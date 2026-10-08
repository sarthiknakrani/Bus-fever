BUS FEVER - FOUNTAIN / GARDEN 2D ASSET PACK

Source: Original fountain-plaza illustration generated during this conversation.
Assets have transparent RGBA backgrounds created by masking/cropping that illustration.
These are artwork cutouts, NOT verified in-game screenshots and NOT guaranteed pixel-perfect at every size.

Files:
  fountain_island_composite.png  (1200 x 420): one-piece compact island for quick prototyping
  fountain_center.png            (745 x 505): fountain and pool, usable separately
  garden_left.png                (388 x 402): left greenery/bench cutout
  garden_right.png               (379 x 397): right greenery/bench cutout

Usage in existing Godot project:
1. Back up existing PlazaEnvironment and inspect current local code first.
2. Copy PNGs into res://assets/sprites/premium_plaza/.
3. Hide/disable current temporary green rectangles, old miniature fountain illustration,
   duplicate procedural rim/water/flower visuals; do not delete gameplay paths.
4. Render garden/plaza art below the GREY passenger walkway and passenger characters.
5. Use either the composite PNG OR independently positioned three sprites, NOT both.
6. Start with 3 separate Sprite2D nodes if one-piece fit is too restrictive:
   left garden - center fountain - right garden.
   Use each sprite's transform/scale carefully so fountain details remain recognizable.
7. Fit artwork within the actual INNER oval, not whole passenger track bounding box.
   Keep margin to moving people. No white rectangular backing.
8. Only the fountain water can have subtle small ripple/splash animation.
   Do not change passenger movement, speeds, boarding, buses or parking.
9. Compare to the actual game window at 720x1280 and at a narrower portrait viewport.
   Capture evidence from gameplay. Confirm no path overlap and Level Clear.

The files contain cutout/soft edges from the source artwork. Zoom in to inspect before integration.
If artifacts are visible, report them and ask for a revised asset, instead of hiding
artifacts with giant rectangles or repainting the environment using placeholders.
