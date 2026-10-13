# Solid white disc for round particles (pot smoke). Supersampled for a smooth edge.
from pathlib import Path
from PIL import Image, ImageDraw

SIZE, SS = 128, 8
big = Image.new("L", (SIZE * SS, SIZE * SS), 0)
ImageDraw.Draw(big).ellipse((SS, SS, SIZE * SS - SS - 1, SIZE * SS - SS - 1), fill=255)
mask = big.resize((SIZE, SIZE), Image.LANCZOS)
out = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
out.putalpha(mask)
out.save(Path(__file__).with_name("Circle.png"))
