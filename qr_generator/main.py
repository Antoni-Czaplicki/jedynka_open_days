import qrcode.main as qrcode
import requests
from PIL import ImageDraw, Image
from PIL import ImageFont

data = requests.get("https://raw.githubusercontent.com/Antoni-Czaplicki/jedynka_open_days/main/data/data.json").json()

checkpoints = data["checkpoints"]

index = 0
for index, checkpoint in enumerate(checkpoints):
    id = checkpoint["id"]
    title = checkpoint["title"]
    img = qrcode.make(id, box_size=20)
    img_w, img_h = img.size

    background = Image.new('RGB',
                           (595, 842),  # A4 at 72dpi
                           (255, 255, 255))  # White
    bg_w, bg_h = background.size
    offset = ((bg_w - img_w) // 2, (bg_h - img_h) // 4)
    background.paste(img, offset)
    fnt = ImageFont.truetype('Roboto-Regular.ttf', 80)
    d = ImageDraw.Draw(background)
    w, h = d.textsize(str(id), font=fnt)
    d.text(((bg_w - w) // 2, 600), str(id), font=fnt, fill=0)
    background.save(f"qr/{title}.png")

print(f"Created {index + 1} qr codes")
