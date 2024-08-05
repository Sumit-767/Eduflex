from PIL import Image
import pytesseract

# Path to the Tesseract executable (change this if it's installed elsewhere)
pytesseract.pytesseract.tesseract_cmd = r'C:\\Program Files\\Tesseract-OCR\\tesseract.exe'

# Function to extract text from image
def extract_text_from_image(image_path):
    try:
        # Open an image file
        img = Image.open(image_path)
        
        # Use Tesseract to do OCR on the image
        text = pytesseract.image_to_string(img)
        
        return text
    except Exception as e:
        return str(e)

# Example usage
image_path = 'C:\\Eduflex\\tesseract\\aaa.jpg'
extracted_text = extract_text_from_image(image_path)
print("Extracted Text:")
print(extracted_text)
