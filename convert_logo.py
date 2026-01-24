from PIL import Image
import os

input_path = r"C:/Users/bayue/.gemini/antigravity/brain/585b9f07-4b80-453a-aaee-bfdb945091b4/logo_solid_black_1769104530011.png"
output_path = r"C:\Users\bayue\Desktop\hpdaerah\hpdaerah\assets\images\logo.png"

# Load image
img = Image.open(input_path).convert("RGBA")

# Create a solid white image
white_img = Image.new("RGBA", img.size, (255, 255, 255, 255))

# Use the grayscale version of the input as the mask
# Black (0) in input -> Transparent (0) in output
# White (255) in input -> Opaque (255) in output
mask = img.convert("L")

# Apply mask to white image
white_img.putalpha(mask)

# Crop the image to remove transparent borders (TRIM)
bbox = white_img.getbbox()
if bbox:
    white_img = white_img.crop(bbox)

# Save result
white_img.save(output_path, "PNG")

print(f"Successfully saved transparent logo to {output_path}")
