import sys
from PIL import Image
# pair.py canvas.png sim.png out.png : stacked, each at half size
a, b = Image.open(sys.argv[1]).convert('RGB'), Image.open(sys.argv[2]).convert('RGB')
w = 960; a = a.resize((w, round(a.height * w / a.width))); b = b.resize((w, round(b.height * w / b.width)))
o = Image.new('RGB', (w, a.height + b.height + 6), (255, 255, 255)); o.paste(a, (0, 0)); o.paste(b, (0, a.height + 6)); o.save(sys.argv[3])
