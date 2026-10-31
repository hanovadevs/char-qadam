# Stepsy · Sage colour variant

`Stepsy-mark-sage.png` is a transparent 1254 × 1254 PNG variant of the existing ribbon-and-footprint mark. The original `mobile/assets/icon/Stepsy_Icon1.png` is preserved. This variant is used in the revised motion ad, mobile branding and generated launcher icons, the admin header/sign-in/favicon, and the repository README.

Runtime copies are `mobile/assets/icon/Stepsy_Icon_sage.png` and `web/public/logo-sage.png`. Keep these byte-identical to this master. From `mobile`, run `dart run flutter_launcher_icons` after changing the master/runtime copy; the configuration uses a cream background and sage web theme.

Palette direction: soft warm sage highlights (`#D6DFC3`, `#A8B895`), muted leaf green (`#869F78`, `#4F6A4D`) and forest folds (`#264A3A`). The PNG retains dimensional shading rather than a flat monochrome fill.

Created with the built-in imagegen edit tool from the existing Stepsy logo, with a transparent background. Prompt:

> Change only the existing logo's colours to match a soft cozy sage/cream app. Preserve the S ribbon silhouette, curvature, fold geometry, footprint tread cutouts, proportions, orientation and shaded dimensional treatment. Recolour turquoise/mint to warm sage, teal shadows to forest and muted green, and highlights to pale sage. No wordmark, background, new shapes, outlines, ornaments or external shadow.

The ad packer frames the visible alpha bounds, ignoring imperceptible alpha=1 specks at the image edges. It embeds the supplied PNG unchanged. For the ad rebuild, use `--logo design/brand/Stepsy-mark-sage.png`.
