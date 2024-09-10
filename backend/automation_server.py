from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright
import os ,re ,nltk, fitz
import pandas as pd
from werkzeug.utils import secure_filename
import pdfplumber
from pdfminer.high_level import extract_pages ,extract_text
from pdfminer.layout import LAParams, LTTextBox, LTTextLine, LTChar
from pdfminer.pdfinterp import PDFResourceManager, PDFPageInterpreter
from pdfminer.converter import PDFPageAggregator
from pdfminer.pdfpage import PDFPage
import pytesseract
from PIL import Image
from nltk.corpus import stopwords

from model import extract_font_information_with_metadata_and_images, prepare_data_for_prediction, model, preprocessor

nltk.download('stopwords')
stop_words = set(stopwords.words('english'))

app = Flask(__name__)
CORS(app)  
UPLOAD_FOLDER = 'apiuploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

HASHTAG_FOLDER = 'hashtag_extraction'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

CERT_DETECTION = 'uploads'

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['HASHTAG_FOLDER'] = HASHTAG_FOLDER
app.config['CERT_DETECTION'] = CERT_DETECTION


#--------------------------------------------------------------------------    UPLOAD
def extract_ids_from_pdf(file_path):
    ids = []
    with pdfplumber.open(file_path) as pdf:
        for page in pdf.pages:
            table = page.extract_table()
            if table:
                for row in table:
                    for cell in row:
                        if cell and cell.isdigit():
                            ids.append(int(cell))
    return ids

def extract_names_from_pdf(file_path):
    names = []
    
    def is_integer(value):
        try:
            word = int(value)
            return True
        except ValueError:
            if(len(value) < 4 ):
                return True
            return False

    with pdfplumber.open(file_path) as pdf:
        for page in pdf.pages:
            table = page.extract_table()
            if table:
                for row in table:
                    for cell in row:
                        if cell and not is_integer(cell):
                            names.append(cell)
    
    return names

def extract_ids_from_excel(file_path):
    ids = []
    df = pd.read_excel(file_path)
    for column in df.columns:
        ids.extend(df[column].dropna().astype(str).str.extract('(\d+)')[0].dropna().astype(int).tolist())
    return ids

def extract_names_from_excel(file_path):
    names = []
    
    def is_integer(value):
        try:
            word = int(value)
            word = float(value)
            return True
        except ValueError:
            if len(value) < 4:
                return True
            return False
    
    df = pd.read_excel(file_path)
    for column in df.columns:
        for value in df[column].dropna().astype(str).tolist():
            if not is_integer(value):
                names.append(value)
    
    return names


def extract_lines_from_pdf(pdf_file):
    extracted_lines = []
    try:
        # Process each page in the PDF
        for page_layout in extract_pages(pdf_file, laparams=LAParams()):
            for element in page_layout:
                if isinstance(element, (LTTextBox, LTTextLine)):
                    # Get text lines from each text element
                    line_text = element.get_text().strip()
                    if line_text:
                        extracted_lines.append(line_text)
    except Exception as e:
        print(f"Error processing PDF: {e}")
        return []
    return extracted_lines

#--------------------------------------------------------------------------    HASHTAG
def extract_text_from_pdf(file_path):
    try:
        # Extract text from PDF
        text = extract_text(file_path)
        # Split the text into lines
        lines = text.split('\n')
        return lines
    except Exception as e:
        print(f"Error extracting text from PDF: {e}")
        return []

def extract_text_from_image(file_path):
    try:
        # Open image file
        img = Image.open(file_path)
        # Extract text using Tesseract
        text = pytesseract.image_to_string(img)
        # Split the text into lines
        lines = text.split('\n')
        return lines
    except Exception as e:
        print(f"Error extracting text from image: {e}")
        return []

def create_hashtags_from_lines(lines):
    hashtags = []
    for line in lines:
        line = line.strip()
        if line:
            # Tokenize the line into words
            words = re.findall(r'\w+', line)
            # Remove stop words and create hashtags from remaining words
            filtered_words = [word for word in words if word.lower() not in stop_words]
            if filtered_words:
                # Join the remaining words with underscores
                hashtag = '#{}'.format('_'.join(filtered_words))
                hashtags.append(hashtag)
    return list(set(hashtags))


##################################################################################        UPLOAD
@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({'message': 'No file part'}), 400

    file = request.files['file']
    selection = request.form.get('selection', 'id')  

    if file.filename == '':
        return jsonify({'message': 'No selected file'}), 400

    if file:
        filename = file.filename
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(file_path)

        if filename.endswith('.pdf'):
            if selection == 'id':
                data = extract_ids_from_pdf(file_path)
            elif selection == 'name':
                data = extract_names_from_pdf(file_path)
            else:
                return jsonify({'message': 'Invalid selection type'}), 400
        elif filename.endswith('.xlsx') or filename.endswith('.xls'):
            if selection == 'id':
                data = extract_ids_from_excel(file_path)
            elif selection == 'name':
                data = extract_names_from_excel(file_path)
            else:
                return jsonify({'message': 'Invalid selection type'}), 400
        
        else:
            return jsonify({'message': 'Unsupported file type'}), 400

        return jsonify({'data': data})

    return jsonify({'message': 'Failed to upload file'}), 500

##################################################################################        HASHTAG

@app.route('/autohash', methods=['POST'])
def extract_hashtags():
    data = request.json
    temp = data.get('filePath')
    mode = data.get('mode')
    
    # Construct the file path
    file_path = os.path.normpath(os.path.join('./', temp))
    
    # Ensure file exists
    if not os.path.isfile(file_path):
        return jsonify({"error": "File not found"}), 404

    try:
        if mode == 'pdf':
            lines = extract_text_from_pdf(file_path)
        elif mode == 'image':
            lines = extract_text_from_image(file_path)
        else:
            return jsonify({"error": "Invalid mode"}), 400
        
        hashtags = create_hashtags_from_lines(lines)
        print(hashtags)
        return jsonify({"hashtags": hashtags})
    
    except Exception as e:
        print(f"Error processing file: {e}")
        return jsonify({"error": "Failed to extract hashtags"}), 500
    

##################################################################################        CREDLY BADGES

@app.route('/fetch-badges', methods=['GET'])
def fetch_badges():
    url = request.args.get('url')
    if not url:
        return jsonify({'error': 'URL parameter is required'}), 400

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto(url)
        
        # Wait for the content to load
        page.wait_for_load_state('networkidle')
    
        # Click the "See all badges" button
        see_all_button = page.locator("text=See all")
        if see_all_button:
            see_all_button.click()
            page.wait_for_load_state('networkidle')
    
        # Get the page content after clicking the button
        html = page.content()
        browser.close()

    # Parse the page content with BeautifulSoup
    soup = BeautifulSoup(html, 'html.parser')

    # Define the classes to search for
    TARGET_CLASSES = {
        "organization_name": "Typographystyles__Container-fredly__sc-1jldzrm-0 enJnLg settings__skills-profile__edit-skills-profile__badge-card__organization-name-two-lines",
        "issuer_name": "Typographystyles__Container-fredly__sc-1jldzrm-0 bcTyRt settings__skills-profile__edit-skills-profile__badge-card__issuer-name-two-lines",
        "issued_date": "Typographystyles__Container-fredly__sc-1jldzrm-0 jdhPUY settings__skills-profile__edit-skills-profile__badge-card__issued"
    }

    # Initialize lists to store extracted elements
    organization_names = []
    issuer_names = []
    issued_dates = []

    # Extract data for each class
    for key, target_class in TARGET_CLASSES.items():
        elements = soup.find_all('div', class_=target_class)
        if key == 'organization_name':
            organization_names = [element.get_text(strip=True) for element in elements]
        elif key == 'issuer_name':
            issuer_names = [element.get_text(strip=True) for element in elements]
        elif key == 'issued_date':
            issued_dates = [element.get_text(strip=True) for element in elements]

    # Combine extracted data into a list of dictionaries
    badges_data = []
    for org, issuer, issued in zip(organization_names, issuer_names, issued_dates):
        badges_data.append({
            "certificate_name": org,
            "issuer_name": issuer,
            "issued_date": issued
        })

    # Return the JSON response
    return jsonify(badges_data)

@app.route('/validate-certificate', methods=['POST'])
def validate_certificate():
    try:
        # Get the JSON data from the request
        data = request.json
        username = data.get('username')
        filename = data.get('filename')
        
        if not username or not filename:
            return jsonify({'error': 'Username and filename are required'}), 400
        
        # Construct the full path for the uploaded file
        file_path = os.path.join(app.config['CERT_DETECTION'], username, secure_filename(filename))
        print("The original file path:", file_path)
        
        # Ensure file exists
        if not os.path.isfile(file_path):
            return jsonify({'error': 'File not found'}), 404
        
        # Process the PDF file
        features = extract_font_information_with_metadata_and_images(file_path)
        if not features:
            return jsonify({'error': 'No features extracted from PDF'}), 500
        
        # Prepare data for prediction
        df = prepare_data_for_prediction(features)
        
        # Apply preprocessing and make predictions
        X_processed = preprocessor.transform(df)
        predictions = model.predict(X_processed)
        
        # Determine the final result
        all_real = True
        fake_producer = None
        
        for i, pred in enumerate(predictions):
            if pred <= 0.5:
                all_real = False
                fake_producer = features[i]['Producer']
                break
        
        if all_real:
            return jsonify({"result": "Real"})
        else:
            return jsonify({"result": "Fake", "Edited_By": f"{fake_producer}"})
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(port=5000)
