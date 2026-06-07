#!/usr/bin/env Rscript
# ============================================================================
# LOGO.R - Generate the ethsign hex sticker
# ============================================================================
# Concept: "Xi Keystone". The Ethereum diamond as the centerpiece, drawn as a
# faceted crystal, with a glowing elliptic-curve line (secp256k1) slicing
# through it and the three signature components r / s / v labelling three
# facets. Neon violet/indigo crystal, cyan signing-slice, on a near-black hex.
#
# Multi-layer compositing: ggplot2 renders the crisp layers, magick applies
# gaussian blur + screen blends for the neon glow (same pipeline as the
# template logo).
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
col_hex_edge <- "#2A2550" # subtle hex border

# Ethereum crystal facets (light source upper-right): lightest -> darkest
col_facet_tr <- "#B9AEFF" # top-right  (lightest)
col_facet_tl <- "#6E5CEA" # top-left
col_facet_br <- "#5544C9" # bottom-right
col_facet_bl <- "#372C8F" # bottom-left (darkest)

col_edge <- "#C9BEFF" # bright facet edges
col_curve <- "#34E1FF" # the secp256k1 signing-slice (cyan)
col_point <- "#7DF9FF" # intersection points on the slice
col_rsv <- "#9FB7FF" # r / s / v labels
col_word <- "#FFFFFF" # wordmark
col_sub <- "#6B6797" # subtitle

# ============================================================================
# Geometry
# ============================================================================

# Ethereum diamond key points (centred, lifted slightly to leave room for the
# wordmark in the lower hex gap).
T <- c(0.00, 0.52) # top apex
L <- c(-0.24, 0.20) # left shoulder
R <- c(0.24, 0.20) # right shoulder
M <- c(0.00, 0.12) # centre waist
B <- c(0.00, -0.20) # bottom apex

facet_tl <- data.frame(x = c(T[1], L[1], M[1]), y = c(T[2], L[2], M[2]))
facet_tr <- data.frame(x = c(T[1], M[1], R[1]), y = c(T[2], M[2], R[2]))
facet_bl <- data.frame(x = c(L[1], M[1], B[1]), y = c(L[2], M[2], B[2]))
facet_br <- data.frame(x = c(M[1], R[1], B[1]), y = c(M[2], R[2], B[2]))

# Silhouette + internal edges (drawn as bright strokes over the facets).
silhouette <- data.frame(
  x = c(T[1], R[1], B[1], L[1], T[1]),
  y = c(T[2], R[2], B[2], L[2], T[2])
)
edge_ridge <- data.frame(x = c(T[1], M[1], B[1]), y = c(T[2], M[2], B[2])) # vertical
edge_waist <- data.frame(x = c(L[1], M[1], R[1]), y = c(L[2], M[2], R[2])) # shoulders

deg2rad <- function(d) d * pi / 180

# Pointy-top hexagon (matches the template sticker orientation).
hex_vertices <- function(cx = 0, cy = 0, r = 1) {
  angles <- seq(pi / 2, pi / 2 + 2 * pi, length.out = 7)[1:6]
  data.frame(x = cx + r * cos(angles), y = cy + r * sin(angles))
}

filled_circle <- function(cx, cy, r, n = 120) {
  a <- seq(0, 2 * pi, length.out = n)
  data.frame(x = cx + r * cos(a), y = cy + r * sin(a))
}

# The signing-slice: a real arc of the secp256k1 curve y^2 = x^3 + 7, scaled
# and rotated so a graceful slice of it cuts diagonally through the diamond.
# We sample the upper branch over a window of x, then affine-place it.
curve_slice <- function() {
  xs <- seq(-1.55, 1.95, length.out = 240)
  ys <- sqrt(pmax(xs^3 + 7, 0))
  # normalise into a compact stroke, then rotate ~22 deg and centre on the waist
  xs <- (xs - mean(range(xs))) * 0.165
  ys <- (ys - mean(range(ys))) * 0.085
  ang <- deg2rad(22)
  data.frame(
    x = M[1] + xs * cos(ang) - ys * sin(ang),
    y = M[2] + 0.02 + xs * sin(ang) + ys * cos(ang)
  )
}

# Two glowing points where the slice meets the crystal (the signed points).
slice_points <- function(cs) {
  data.frame(
    x = c(cs$x[35], cs$x[205]),
    y = c(cs$y[35], cs$y[205])
  )
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
# Layer 1: Base (hex, crystal facets, edges, slice, r/s/v, wordmark)
# ============================================================================

build_base_layer <- function() {
  cs <- curve_slice()
  pts <- slice_points(cs)
  hex <- hex_vertices(0, 0, 0.57)

  ggplot() +
    # Hex body
    geom_polygon(data = hex, aes(x, y), fill = col_hex_fill, colour = col_hex_edge, linewidth = 1.2) +
    # Crystal facets
    geom_polygon(data = facet_bl, aes(x, y), fill = col_facet_bl, colour = NA) +
    geom_polygon(data = facet_br, aes(x, y), fill = col_facet_br, colour = NA) +
    geom_polygon(data = facet_tl, aes(x, y), fill = col_facet_tl, colour = NA) +
    geom_polygon(data = facet_tr, aes(x, y), fill = col_facet_tr, colour = NA) +
    # Bright facet edges
    geom_path(data = edge_waist, aes(x, y), colour = col_edge, linewidth = 0.9, alpha = 0.85) +
    geom_path(data = edge_ridge, aes(x, y), colour = col_edge, linewidth = 0.9, alpha = 0.85) +
    geom_path(data = silhouette, aes(x, y), colour = col_edge, linewidth = 1.7) +
    # secp256k1 signing-slice
    geom_path(data = cs, aes(x, y), colour = col_curve, linewidth = 2.0, lineend = "round") +
    geom_point(data = pts, aes(x, y), colour = col_point, size = 3.1) +
    # r / s / v on three facets
    annotate("text", x = 0.085, y = 0.30, label = "r", colour = col_rsv, size = 6, fontface = "italic") +
    annotate("text", x = 0.105, y = 0.02, label = "s", colour = col_rsv, size = 6, fontface = "italic") +
    annotate("text", x = -0.105, y = 0.02, label = "v", colour = col_rsv, size = 6, fontface = "italic") +
    # Wordmark + subtitle in the lower gap
    annotate("text", x = 0, y = -0.37, label = "ethsign", colour = col_word, size = 10.5, fontface = "bold") +
    annotate("text", x = 0, y = -0.475, label = "secp256k1 . eip-712", colour = col_sub, size = 3.8) +
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
    # Slice glow
    geom_path(data = cs, aes(x, y), colour = col_curve, linewidth = 3.0, lineend = "round") +
    geom_point(data = pts, aes(x, y), colour = col_point, size = 8) +
    # Silhouette + edge glow
    geom_path(data = silhouette, aes(x, y), colour = col_edge, linewidth = 2.4) +
    geom_path(data = edge_ridge, aes(x, y), colour = col_edge, linewidth = 1.4, alpha = 0.8) +
    geom_path(data = edge_waist, aes(x, y), colour = col_edge, linewidth = 1.4, alpha = 0.8) +
    # Warm ambient core behind the crystal
    geom_polygon(data = filled_circle(0, 0.07, 0.05), aes(x, y), fill = "#8E7BFF80", colour = NA) +
    annotate("point", x = 0, y = 0.07, size = 26, colour = "#6E5CEA20", shape = 16) +
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
  glow_wide <- image_blur(glow_img, radius = 0, sigma = 42)
  glow_mid <- image_blur(glow_img, radius = 0, sigma = 20)
  glow_tight <- image_blur(glow_img, radius = 0, sigma = 8)

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
