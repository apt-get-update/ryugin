// The cover's dominant colour, to tint the UI after the song that plays, and its wash:
// the blurred backdrop of the fullscreen player.
package main

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"image"
	_ "image/jpeg"
	"image/png"
	"math"
	"net/http"
	"time"
)

// coverLook downloads a (small) cover and returns its colour and its two backdrops (wash
// for a window whose longer side is side, and flow).
func coverLook(url string, side float64) (string, string, string, error) {
	client := http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return "", "", "", err
	}
	defer resp.Body.Close()
	img, _, err := image.Decode(resp.Body)
	if err != nil {
		return "", "", "", err
	}
	return dominant(img), wash(img, side), flow(img), nil
}

// dominant is the cover's most present vivid colour as #rrggbb: hues are counted
// weighted by saturation and brightness, and the winning hue's pixels are averaged.
// A grey cover gives its average grey.
func dominant(img image.Image) string {
	const bins = 36
	var weight [bins]float64
	var sum [bins][3]float64
	var all [3]float64
	n := 0.0
	b := img.Bounds()
	step := max(1, b.Dx()/64)
	for y := b.Min.Y; y < b.Max.Y; y += step {
		for x := b.Min.X; x < b.Max.X; x += step {
			r16, g16, b16, _ := img.At(x, y).RGBA()
			r, g, bl := float64(r16)/65535, float64(g16)/65535, float64(b16)/65535
			all[0], all[1], all[2] = all[0]+r, all[1]+g, all[2]+bl
			n++
			h, s, v := hsv(r, g, bl)
			if s < 0.2 || v < 0.15 {
				continue
			}
			i := int(h*bins) % bins
			w := s * v
			weight[i] += w
			sum[i][0], sum[i][1], sum[i][2] = sum[i][0]+r*w, sum[i][1]+g*w, sum[i][2]+bl*w
		}
	}
	best := 0
	for i := range weight {
		if weight[i] > weight[best] {
			best = i
		}
	}
	c := [3]float64{all[0] / n, all[1] / n, all[2] / n}
	if weight[best] > 0.02*n {
		w := weight[best]
		c = [3]float64{sum[best][0] / w, sum[best][1] / w, sum[best][2] / w}
	}
	return fmt.Sprintf("#%02x%02x%02x", int(math.Round(c[0]*255)), int(math.Round(c[1]*255)), int(math.Round(c[2]*255)))
}

// wash is the backdrop of the fullscreen player, as SPlayer-Next's default ("blur"): the
// cover filling the window, CSS blur(45px) saturate(1.2). The blur is 45 px of the cover
// drawn as large as the window's longer side (side). wash.frag scales it 1.5x and darkens
// it by half. It is a 128x128 PNG data URL.
func wash(img image.Image, side float64) string {
	const n = 128
	px := make([][3]float64, n*n)
	b := img.Bounds()
	for y := 0; y < n; y++ {
		for x := 0; x < n; x++ {
			r, g, bl, _ := img.At(b.Min.X+(2*x+1)*b.Dx()/(2*n), b.Min.Y+(2*y+1)*b.Dy()/(2*n)).RGBA()
			px[y*n+x] = [3]float64{float64(r) / 65535, float64(g) / 65535, float64(bl) / 65535}
		}
	}
	blur(px, n, gauss(45/max(side, 100)*n))
	const s = 1.2 // CSS saturate()
	out := image.NewNRGBA(image.Rect(0, 0, n, n))
	for i, c := range px {
		r := (0.213+0.787*s)*c[0] + (0.715-0.715*s)*c[1] + (0.072-0.072*s)*c[2]
		g := (0.213-0.213*s)*c[0] + (0.715+0.285*s)*c[1] + (0.072-0.072*s)*c[2]
		bl := (0.213-0.213*s)*c[0] + (0.715-0.715*s)*c[1] + (0.072+0.928*s)*c[2]
		for k, v := range []float64{r, g, bl} {
			out.Pix[4*i+k] = uint8(math.Round(255 * math.Max(0, math.Min(1, v))))
		}
		out.Pix[4*i+3] = 255
	}
	var buf bytes.Buffer
	_ = png.Encode(&buf, out) // into memory: no error
	return "data:image/png;base64," + base64.StdEncoding.EncodeToString(buf.Bytes())
}

// gauss is a Gaussian blur kernel, its weights summing to 1.
func gauss(sigma float64) []float64 {
	r := int(math.Ceil(3 * sigma))
	k := make([]float64, 2*r+1)
	sum := 0.0
	for i := range k {
		d := float64(i - r)
		k[i] = math.Exp(-d * d / (2 * sigma * sigma))
		sum += k[i]
	}
	for i := range k {
		k[i] /= sum
	}
	return k
}

// blur blurs a square n x n image in place with a kernel (weights summing to 1), across
// then down, edges held.
func blur(px [][3]float64, n int, k []float64) {
	r := len(k) / 2
	tmp := make([][3]float64, len(px))
	across := func(a, b int) int { return a*n + b }
	down := func(a, b int) int { return b*n + a }
	for _, idx := range []func(a, b int) int{across, down} {
		for a := range n {
			for b := range n {
				var c [3]float64
				for i, w := range k {
					p := px[idx(a, max(0, min(n-1, b+i-r)))]
					for ch := range c {
						c[ch] += p[ch] * w
					}
				}
				tmp[idx(a, b)] = c
			}
		}
		copy(px, tmp)
	}
}

func hsv(r, g, b float64) (h, s, v float64) {
	mx, mn := math.Max(r, math.Max(g, b)), math.Min(r, math.Min(g, b))
	v = mx
	if mx == 0 {
		return 0, 0, 0
	}
	s = (mx - mn) / mx
	if mx == mn {
		return 0, s, v
	}
	switch mx {
	case r:
		h = (g - b) / (mx - mn)
	case g:
		h = 2 + (b-r)/(mx-mn)
	default:
		h = 4 + (r-g)/(mx-mn)
	}
	h /= 6
	if h < 0 {
		h++
	}
	return h, s, v
}

// flow is the other fullscreen backdrop, SPlayer-Next's "fluid" one (AMLL's
// MeshGradientRenderer.setAlbum): the cover shrunk to 32x32 (one pixel per cell, as the
// browser's low-quality resize), contrast x0.4, saturation x3, contrast x1.7, x0.75, then
// a box blur of radius 2, 4 passes. flow.vert/flow.frag bend and turn it like AMLL's
// shaders. It is a 32x32 PNG data URL.
func flow(img image.Image) string {
	const n = 32
	px := make([][3]float64, n*n)
	b := img.Bounds()
	for y := 0; y < n; y++ {
		for x := 0; x < n; x++ {
			r, g, bl, _ := img.At(b.Min.X+(2*x+1)*b.Dx()/(2*n), b.Min.Y+(2*y+1)*b.Dy()/(2*n)).RGBA()
			px[y*n+x] = [3]float64{float64(r) / 257, float64(g) / 257, float64(bl) / 257}
		}
	}
	for i, c := range px {
		for k := range c {
			c[k] = (c[k]-128)*0.4 + 128
		}
		gray := c[0]*0.3 + c[1]*0.59 + c[2]*0.11
		for k := range c {
			c[k] = ((gray*-2+c[k]*3)-128)*1.7 + 128
			c[k] = math.Round(math.Max(0, math.Min(255, c[k]*0.75))) // a canvas keeps bytes
		}
		px[i] = c
	}
	for range 4 { // four box passes: nearly a Gaussian, cheaper
		blur(px, n, []float64{0.2, 0.2, 0.2, 0.2, 0.2})
	}
	out := image.NewNRGBA(image.Rect(0, 0, n, n))
	for i, c := range px {
		out.Pix[4*i], out.Pix[4*i+1], out.Pix[4*i+2], out.Pix[4*i+3] = uint8(math.Round(c[0])), uint8(math.Round(c[1])), uint8(math.Round(c[2])), 255
	}
	var buf bytes.Buffer
	_ = png.Encode(&buf, out) // into memory: no error
	return "data:image/png;base64," + base64.StdEncoding.EncodeToString(buf.Bytes())
}
