from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

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
