#!/usr/bin/env Rscript
# ============================================================================
# LOGO.R - Generate the ethsign hex sticker
# ============================================================================
# Concept: "Xi Keystone". The Ethereum diamond as the centerpiece, drawn as a
# faceted crystal, with a glowing elliptic-curve line (secp256k1) slicing
# through it and the three signature components r / s / v labelling three
# facets. Neon violet/indigo crystal, cyan signing-slice, thick violet frame,
# on a near-black hex.
#
# Multi-layer compositing: ggplot2 renders the crisp layers, magick applies
# gaussian blur + screen blends for the neon glow.
#
# Usage:  Rscript scripts/LOGO.R   (or: LOGO_GENERATE=true Rscript scripts/LOGO.R)
# Deps:   ggplot2, magick
# ============================================================================

library(ggplot2)
library(magick)

# ============================================================================
# Palette
# ============================================================================

col_hex_fill <- "#0B0A14" # near-black indigo
col_hex_border <- "#4A3F9E" # thick violet frame

# Ethereum crystal facets (light source upper-right): lightest -> darkest
col_facet_tr <- "#B9AEFF" # top-right  (lightest)
col_facet_tl <- "#6E5CEA" # top-left
col_facet_br <- "#5544C9" # bottom-right
col_facet_bl <- "#372C8F" # bottom-left (darkest)

col_edge <- "#D6CEFF" # bright facet edges
col_curve <- "#45E9FF" # the secp256k1 signing-slice (bright cyan)
col_point <- "#CFFBFF" # intersection points on the slice
col_rsv <- "#F2F5FF" # r / s / v labels (near-white, bright)
col_word <- "#FFFFFF" # wordmark
col_sub <- "#8C88B8" # subtitle

# ============================================================================
# Geometry
# ============================================================================

# Ethereum diamond key points. Lowered toward the hex centre, with the wordmark
# tucked into the lower gap.
TT <- c(0.00, 0.435) # top apex
LL <- c(-0.22, 0.135) # left shoulder
RR <- c(0.22, 0.135) # right shoulder
MM <- c(0.00, 0.065) # centre waist
BB <- c(0.00, -0.255) # bottom apex

facet_tl <- data.frame(x = c(TT[1], LL[1], MM[1]), y = c(TT[2], LL[2], MM[2]))
facet_tr <- data.frame(x = c(TT[1], MM[1], RR[1]), y = c(TT[2], MM[2], RR[2]))
facet_bl <- data.frame(x = c(LL[1], MM[1], BB[1]), y = c(LL[2], MM[2], BB[2]))
facet_br <- data.frame(x = c(MM[1], RR[1], BB[1]), y = c(MM[2], RR[2], BB[2]))

# Closed silhouette (drawn as a polygon so the sharp apex joins cleanly with a
# mitre and leaves no notch/divot).
silhouette <- data.frame(
  x = c(TT[1], RR[1], BB[1], LL[1]),
  y = c(TT[2], RR[2], BB[2], LL[2])
)
edge_ridge <- data.frame(x = c(TT[1], MM[1], BB[1]), y = c(TT[2], MM[2], BB[2])) # vertical
edge_waist <- data.frame(x = c(LL[1], MM[1], RR[1]), y = c(LL[2], MM[2], RR[2])) # shoulders

deg2rad <- function(d) d * pi / 180

# Pointy-top hexagon.
hex_vertices <- function(cx = 0, cy = 0, r = 1) {
  angles <- seq(pi / 2, pi / 2 + 2 * pi, length.out = 7)[1:6]
  data.frame(x = cx + r * cos(angles), y = cy + r * sin(angles))
}

filled_circle <- function(cx, cy, r, n = 120) {
  a <- seq(0, 2 * pi, length.out = n)
  data.frame(x = cx + r * cos(a), y = cy + r * sin(a))
}

# The signing-slice: a real arc of secp256k1's curve y^2 = x^3 + 7, scaled
# (bigger) and rotated so a graceful slice cuts diagonally through the diamond.
curve_slice <- function() {
  xs <- seq(-1.55, 1.95, length.out = 240)
  ys <- sqrt(pmax(xs^3 + 7, 0))
  xs <- (xs - mean(range(xs))) * 0.205
  ys <- (ys - mean(range(ys))) * 0.105
  ang <- deg2rad(22)
  data.frame(
    x = MM[1] + xs * cos(ang) - ys * sin(ang),
    y = MM[2] + 0.01 + xs * sin(ang) + ys * cos(ang)
  )
}

slice_points <- function(cs) {
  data.frame(x = c(cs$x[40], cs$x[200]), y = c(cs$y[40], cs$y[200]))
}

logo_theme <- function() {
  theme_void() +
    theme(
      plot.background = element_rect(fill = "transparent", colour = NA),
      panel.background = element_rect(fill = "transparent", colour = NA),
      plot.margin = margin(0, 0, 0, 0)
    )
}

logo_coord <- function() coord_equal(xlim = c(-0.67, 0.67), ylim = c(-0.67, 0.67))

render_layer <- function(p, width = 3000, height = 3480) {
  tmp <- tempfile(fileext = ".png")
  ggsave(tmp, plot = p, width = width / 600, height = height / 600, dpi = 600, bg = "transparent")
  img <- image_read(tmp)
  unlink(tmp)
  img
}

# ============================================================================
# Layer 1: Base (thick-framed hex, crystal, slice, r/s/v, wordmark)
# ============================================================================

build_base_layer <- function() {
  cs <- curve_slice()
  pts <- slice_points(cs)
  hex_outer <- hex_vertices(0, 0, 0.57)
  hex_inner <- hex_vertices(0, 0, 0.505) # inner edge of the thick frame

  ggplot() +
    # Thick frame = outer hex (border colour) with inner hex (fill) on top
    geom_polygon(data = hex_outer, aes(x, y), fill = col_hex_border, colour = NA) +
    geom_polygon(data = hex_inner, aes(x, y), fill = col_hex_fill, colour = NA) +
    # Crystal facets
    geom_polygon(data = facet_bl, aes(x, y), fill = col_facet_bl, colour = NA) +
    geom_polygon(data = facet_br, aes(x, y), fill = col_facet_br, colour = NA) +
    geom_polygon(data = facet_tl, aes(x, y), fill = col_facet_tl, colour = NA) +
    geom_polygon(data = facet_tr, aes(x, y), fill = col_facet_tr, colour = NA) +
    # Thin internal edges, then the clean bright silhouette on top (closed
    # polygon, mitre join -> sharp apex, no divot)
    geom_path(data = edge_waist, aes(x, y), colour = col_edge, linewidth = 0.7, alpha = 0.7, lineend = "round") +
    geom_path(data = edge_ridge, aes(x, y), colour = col_edge, linewidth = 0.7, alpha = 0.7, lineend = "round") +
    geom_polygon(data = silhouette, aes(x, y), fill = NA, colour = col_edge, linewidth = 2.0, linejoin = "mitre") +
    # secp256k1 signing-slice (thicker, bigger, brighter)
    geom_path(data = cs, aes(x, y), colour = col_curve, linewidth = 3.6, lineend = "round") +
    geom_point(data = pts, aes(x, y), colour = col_point, size = 4.2) +
    # r / s / v out on the black background, flanking the crystal
    annotate("text", x = 0.37, y = 0.235, label = "r", colour = col_rsv, size = 7.5, fontface = "bold.italic") +
    annotate("text", x = 0.40, y = -0.075, label = "s", colour = col_rsv, size = 7.5, fontface = "bold.italic") +
    annotate("text", x = -0.40, y = -0.075, label = "v", colour = col_rsv, size = 7.5, fontface = "bold.italic") +
    # Wordmark + subtitle in the lower gap (sized to sit inside the frame)
    annotate("text", x = 0, y = -0.35, label = "ethsign", colour = col_word, size = 8, fontface = "bold") +
    annotate("text", x = 0, y = -0.435, label = "secp256k1", colour = col_sub, size = 3.0) +
    logo_coord() +
    logo_theme()
}

# ============================================================================
# Layer 2: Glow sources (bright shapes to blur into a neon halo)
# ============================================================================

build_glow_layer <- function() {
  cs <- curve_slice()
  pts <- slice_points(cs)

  ggplot() +
    # Slice glow (fat + bright)
    geom_path(data = cs, aes(x, y), colour = col_curve, linewidth = 6.0, lineend = "round") +
    geom_point(data = pts, aes(x, y), colour = col_point, size = 12) +
    # Silhouette + edge glow
    geom_polygon(data = silhouette, aes(x, y), fill = NA, colour = col_edge, linewidth = 2.6, linejoin = "mitre") +
    geom_path(data = edge_ridge, aes(x, y), colour = col_edge, linewidth = 1.2, alpha = 0.7) +
    geom_path(data = edge_waist, aes(x, y), colour = col_edge, linewidth = 1.2, alpha = 0.7) +
    # r / s / v halo so the labels read as lit
    annotate("text", x = 0.37, y = 0.235, label = "r", colour = col_rsv, size = 7.5, fontface = "bold.italic") +
    annotate("text", x = 0.40, y = -0.075, label = "s", colour = col_rsv, size = 7.5, fontface = "bold.italic") +
    annotate("text", x = -0.40, y = -0.075, label = "v", colour = col_rsv, size = 7.5, fontface = "bold.italic") +
    # Warm ambient core behind the crystal
    geom_polygon(data = filled_circle(0, 0.08, 0.05), aes(x, y), fill = "#8E7BFF80", colour = NA) +
    annotate("point", x = 0, y = 0.08, size = 26, colour = "#6E5CEA20", shape = 16) +
    logo_coord() +
    logo_theme()
}

# ============================================================================
# Composite with magick
# ============================================================================

generate_logo <- function(
  output_path = file.path("man", "figures", "logo.png"),
  px_width = 3000,
  px_height = 3480
) {
  message("Rendering base layer...")
  base_img <- render_layer(build_base_layer(), px_width, px_height)

  message("Rendering glow layer...")
  glow_img <- render_layer(build_glow_layer(), px_width, px_height)

  message("Blurring glow sources...")
  glow_wide <- image_blur(glow_img, radius = 0, sigma = 40)
  glow_mid <- image_blur(glow_img, radius = 0, sigma = 18)
  glow_tight <- image_blur(glow_img, radius = 0, sigma = 7)

  message("Compositing layers...")
  final <- base_img |>
    image_composite(glow_wide, operator = "screen") |>
    image_composite(glow_mid, operator = "screen") |>
    image_composite(glow_tight, operator = "screen") |>
    image_composite(render_layer(build_base_layer(), px_width, px_height), operator = "over")

  final <- image_trim(final)

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  image_write(final, output_path, format = "png")
  message("Logo saved to: ", output_path)

  for (dest in c("docs/logo.png", "docs/reference/figures/logo.png")) {
    if (dir.exists(dirname(dest))) {
      file.copy(output_path, dest, overwrite = TRUE)
      message("Copied to:    ", dest)
    }
  }

  invisible(final)
}

# ============================================================================
# Run
# ============================================================================

if (!interactive() || identical(Sys.getenv("LOGO_GENERATE"), "true")) {
  generate_logo()
} else {
  message("Source this file and call generate_logo() to create the sticker.")
  message("Or run: Rscript scripts/LOGO.R")
}
