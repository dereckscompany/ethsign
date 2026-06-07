#!/usr/bin/env Rscript
# ============================================================================
# LOGO.R - Generate the ethsign hex sticker
# ============================================================================
# Concept: "Xi Keystone". The Ethereum diamond as a faceted crystal sitting on
# the full secp256k1 curve (y^2 = x^3 + 7). The whole curve is drawn faint; a
# bright cyan arc -- the active signing slice -- rides the upper branch, with a
# couple of glowing nodes and a faint secant hinting at the elliptic-curve
# group law. A specular highlight lifts the crystal. Thick violet frame,
# near-black hex.
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

col_facet_tr <- "#B9AEFF" # top-right  (lightest)
col_facet_tl <- "#6E5CEA" # top-left
col_facet_br <- "#5544C9" # bottom-right
col_facet_bl <- "#372C8F" # bottom-left (darkest)

col_edge <- "#D6CEFF" # bright facet edges
col_curve_dim <- "#3A6E86" # faint full curve (dim teal)
col_curve <- "#45E9FF" # bright signing-slice (cyan)
col_point <- "#CFFBFF" # glowing nodes on the slice
col_secant <- "#7FD8E8" # faint group-law secant
col_spark <- "#FFFFFF" # crystal highlight / sparkle
col_word <- "#FFFFFF" # wordmark
col_sub <- "#8C88B8" # subtitle

# ============================================================================
# Crystal geometry
# ============================================================================

TT <- c(0.00, 0.435) # top apex
LL <- c(-0.22, 0.135) # left shoulder
RR <- c(0.22, 0.135) # right shoulder
MM <- c(0.00, 0.065) # centre waist
BB <- c(0.00, -0.255) # bottom apex

facet_tl <- data.frame(x = c(TT[1], LL[1], MM[1]), y = c(TT[2], LL[2], MM[2]))
facet_tr <- data.frame(x = c(TT[1], MM[1], RR[1]), y = c(TT[2], MM[2], RR[2]))
facet_bl <- data.frame(x = c(LL[1], MM[1], BB[1]), y = c(LL[2], MM[2], BB[2]))
facet_br <- data.frame(x = c(MM[1], RR[1], BB[1]), y = c(MM[2], RR[2], BB[2]))

silhouette <- data.frame(x = c(TT[1], RR[1], BB[1], LL[1]), y = c(TT[2], RR[2], BB[2], LL[2]))
edge_ridge <- data.frame(x = c(TT[1], MM[1], BB[1]), y = c(TT[2], MM[2], BB[2]))
edge_waist <- data.frame(x = c(LL[1], MM[1], RR[1]), y = c(LL[2], MM[2], RR[2]))

# Specular highlight: a bright streak down the upper-right facet edge.
highlight <- data.frame(
  x = c(TT[1] + 0.015, RR[1] - 0.02),
  y = c(TT[2] - 0.03, RR[2] + 0.03)
)

deg2rad <- function(d) d * pi / 180

# ============================================================================
# secp256k1 curve (shared affine transform: full curve, slice, nodes, secant)
# ============================================================================

CURVE_ANGLE <- deg2rad(18)
CURVE_XC <- -0.45 # math-x mapped onto the rotation origin
CURVE_SX <- 0.256
CURVE_SY <- 0.081
CURVE_CX <- 0.00 # plot translate
CURVE_CY <- -0.045
X0 <- -(7^(1 / 3)) # ~ -1.913: the nose, where y = 0

# math (x, y) -> plot coords
tf <- function(mx, my) {
  xx <- (mx - CURVE_XC) * CURVE_SX
  yy <- my * CURVE_SY
  data.frame(
    x = CURVE_CX + xx * cos(CURVE_ANGLE) - yy * sin(CURVE_ANGLE),
    y = CURVE_CY + xx * sin(CURVE_ANGLE) + yy * cos(CURVE_ANGLE)
  )
}

curve_branch <- function(x_from, x_to, sign = 1, n = 220) {
  xs <- seq(x_from, x_to, length.out = n)
  tf(xs, sign * sqrt(pmax(xs^3 + 7, 0)))
}

# Whole curve (both branches). The lower branch is kept shorter than the upper
# so its right-hand end stays clear of the border.
full_curve <- function(xmax_up = 0.80, xmax_lo = 0.58) {
  rbind(curve_branch(xmax_lo, X0, sign = -1), curve_branch(X0, xmax_up, sign = 1))
}

# Bright active arc on the upper branch -- the part that cuts through the crystal.
slice_curve <- function() curve_branch(-1.45, 0.72, sign = 1, n = 260)

# The two glowing nodes sit at the ends of the bright slice.
slice_ends <- function() {
  sc <- slice_curve()
  sc[c(1L, nrow(sc)), ]
}

# ============================================================================
# Hex + small helpers
# ============================================================================

hex_vertices <- function(cx = 0, cy = 0, r = 1) {
  angles <- seq(pi / 2, pi / 2 + 2 * pi, length.out = 7)[1:6]
  data.frame(x = cx + r * cos(angles), y = cy + r * sin(angles))
}

filled_circle <- function(cx, cy, r, n = 120) {
  a <- seq(0, 2 * pi, length.out = n)
  data.frame(x = cx + r * cos(a), y = cy + r * sin(a))
}

# A 4-point sparkle star.
sparkle <- function(cx, cy, r) {
  data.frame(
    x = c(cx, cx + r * 0.28, cx + r, cx + r * 0.28, cx, cx - r * 0.28, cx - r, cx - r * 0.28),
    y = c(cy + r, cy + r * 0.28, cy, cy - r * 0.28, cy - r, cy - r * 0.28, cy, cy + r * 0.28)
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
# Layer 1: Base
# ============================================================================

build_base_layer <- function() {
  fc <- full_curve()
  sc <- slice_curve()
  ends <- slice_ends()
  hex_outer <- hex_vertices(0, 0, 0.57)
  hex_inner <- hex_vertices(0, 0, 0.505)

  ggplot() +
    # Thick frame
    geom_polygon(data = hex_outer, aes(x, y), fill = col_hex_border, colour = NA) +
    geom_polygon(data = hex_inner, aes(x, y), fill = col_hex_fill, colour = NA) +
    # Faint full secp256k1 curve, behind everything
    geom_path(data = fc, aes(x, y), colour = col_curve_dim, linewidth = 2.0, alpha = 0.62, lineend = "round") +
    # Crystal facets
    geom_polygon(data = facet_bl, aes(x, y), fill = col_facet_bl, colour = NA) +
    geom_polygon(data = facet_br, aes(x, y), fill = col_facet_br, colour = NA) +
    geom_polygon(data = facet_tl, aes(x, y), fill = col_facet_tl, colour = NA) +
    geom_polygon(data = facet_tr, aes(x, y), fill = col_facet_tr, colour = NA) +
    # Crystal edges + clean silhouette
    geom_path(data = edge_waist, aes(x, y), colour = col_edge, linewidth = 0.7, alpha = 0.7, lineend = "round") +
    geom_path(data = edge_ridge, aes(x, y), colour = col_edge, linewidth = 0.7, alpha = 0.7, lineend = "round") +
    geom_polygon(data = silhouette, aes(x, y), fill = NA, colour = col_edge, linewidth = 2.0, linejoin = "mitre") +
    # Bright signing-slice + nodes (P, Q on the bright arc; R on the lower branch)
    geom_path(data = sc, aes(x, y), colour = col_curve, linewidth = 4.3, lineend = "round") +
    geom_point(data = ends, aes(x, y), colour = col_point, size = 4.6) +
    # Wordmark + subtitle
    annotate("text", x = 0, y = -0.33, label = "ethsign", colour = col_word, size = 8, fontface = "bold") +
    annotate("text", x = 0, y = -0.405, label = "secp256k1", colour = col_sub, size = 3.0) +
    logo_coord() +
    logo_theme()
}

# ============================================================================
# Layer 2: Glow sources
# ============================================================================

build_glow_layer <- function() {
  sc <- slice_curve()
  ends <- slice_ends()

  ggplot() +
    geom_path(data = sc, aes(x, y), colour = col_curve, linewidth = 7.2, lineend = "round") +
    geom_point(data = ends, aes(x, y), colour = col_point, size = 12) +
    geom_polygon(data = silhouette, aes(x, y), fill = NA, colour = col_edge, linewidth = 2.6, linejoin = "mitre") +
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
