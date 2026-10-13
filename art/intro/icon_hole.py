"""Builds IconHole.png: solid black with the Superchefs icon cut out as a transparent hole.

The path is the Figma vector "icon cutout" (exported as SVG). The hole is centred and fills
HOLE_FRACTION of the image, leaving a black border so the overlay still covers the screen
edges while it is small. Run: python art/intro/icon_hole.py
"""

import os
import re

from PIL import Image, ImageDraw

PATH = (
	"M195.771 585.661L283.271 723.161L299.771 716.161C299.771 716.161 335.638 729.167 519.271 670.161"
	"C691.771 614.733 701.271 570.161 701.271 570.161C701.271 570.161 708.771 572.161 717.271 568.161"
	"C721.271 550.161 709.271 447.161 712.271 402.661C704.447 402.308 691.771 402.661 691.771 402.661"
	"L713.271 132.661L685.271 99.6611L686.271 77.6611C686.271 77.6611 672.271 21.6611 514.771 3.66109"
	"C509.771 -0.838836 378.771 -8.33889 351.771 44.6611C312.271 -1.8389 200.771 34.4982 116.771 90.1611"
	"C-90.7289 227.661 42.7707 303.661 42.7707 303.661C21.2711 330.161 17.7708 368.161 17.7708 368.161"
	"L216.771 574.161L195.771 585.661Z"
)
SIZE = 1024
HOLE_FRACTION = 0.7
SUPERSAMPLE = 4


def flatten(path: str) -> list[tuple[float, float]]:
	tokens = re.findall(r"[MLCZ]|-?\d*\.?\d+(?:e-?\d+)?", path)
	points: list[tuple[float, float]] = []
	i = 0
	command = ""
	while i < len(tokens):
		if tokens[i] in "MLCZ":
			command = tokens[i]
			i += 1
			if command == "Z":
				continue
		if command in "ML":
			points.append((float(tokens[i]), float(tokens[i + 1])))
			i += 2
		elif command == "C":
			x0, y0 = points[-1]
			x1, y1, x2, y2, x3, y3 = (float(t) for t in tokens[i : i + 6])
			i += 6
			for step in range(1, 33):
				t = step / 32
				u = 1 - t
				points.append((
					u**3 * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t**3 * x3,
					u**3 * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t**3 * y3,
				))
	return points


def main() -> None:
	points = flatten(PATH)
	xs = [p[0] for p in points]
	ys = [p[1] for p in points]
	width, height = max(xs) - min(xs), max(ys) - min(ys)
	big = SIZE * SUPERSAMPLE
	scale = big * HOLE_FRACTION / max(width, height)
	cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
	polygon = [((x - cx) * scale + big / 2, (y - cy) * scale + big / 2) for x, y in points]
	alpha = Image.new("L", (big, big), 255)
	ImageDraw.Draw(alpha).polygon(polygon, fill=0)
	alpha = alpha.resize((SIZE, SIZE), Image.LANCZOS)
	image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
	image.putalpha(alpha)
	image.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), "IconHole.png"))


if __name__ == "__main__":
	main()
