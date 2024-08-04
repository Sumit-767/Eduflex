from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright
import os
import pandas as pd
import pdfplumber

app = Flask(__name__)
CORS(app)  
UPLOAD_FOLDER = 'apiuploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

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
    df = pd.read_excel(file_path)
    for column in df.columns:
        names.extend(df[column].dropna().astype(str).tolist())
    return names

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({'message': 'No file part'}), 400

    file = request.files['file']
    selection = request.form.get('selection', 'id')  # Default to 'id' if not specified

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

if __name__ == '__main__':
    app.run(port=5000)
