import numpy as np
import pandas as pd
from tensorflow.keras.models import load_model
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.compose import ColumnTransformer
from pdfminer.layout import LAParams, LTTextBox, LTTextLine, LTChar
from pdfminer.pdfinterp import PDFResourceManager, PDFPageInterpreter
from pdfminer.converter import PDFPageAggregator
from pdfminer.pdfpage import PDFPage
import fitz

# Load the saved Keras model
model = load_model('./certificate_classifier_keras_model.h5')

# Define preprocessing steps
categorical_features = ['Font Style', 'Producer']
numerical_features = ['Font Size', 'Color', 'Image Count']

categorical_transformer = OneHotEncoder(handle_unknown='ignore')
numerical_transformer = StandardScaler()

preprocessor = ColumnTransformer(
    transformers=[
        ('num', numerical_transformer, numerical_features),
        ('cat', categorical_transformer, categorical_features)
    ])

# Load training data to fit preprocessor
real_data = pd.read_csv("./real_cert.csv")
fake_data = pd.read_csv("./fake_cert.csv")
data = pd.concat([real_data, fake_data], ignore_index=True)
X = data.drop(columns=['Label', 'Text'])
preprocessor.fit(X)

def extract_metadata(pdf_file):
    try:
        document = fitz.open(pdf_file)
        metadata = document.metadata
        return metadata
    except Exception as e:
        print("Error extracting metadata from {}: {}".format(pdf_file, e))
        return {}

def extract_font_information(pdf_file):
    font_data = []
    
    # Attempt extraction with pdfminer
    try:
        with open(pdf_file, 'rb') as file:
            rsrcmgr = PDFResourceManager()
            laparams = LAParams()
            device = PDFPageAggregator(rsrcmgr, laparams=laparams)
            interpreter = PDFPageInterpreter(rsrcmgr, device)
            for page_number, page in enumerate(PDFPage.get_pages(file), start=1):
                interpreter.process_page(page)
                layout = device.get_result()
                for element in layout:
                    if isinstance(element, (LTTextBox, LTTextLine)):
                        for text_line in element:
                            line_text = text_line.get_text().strip()
                            for char in text_line:
                                if isinstance(char, LTChar):
                                    color = getattr(char.graphicstate, 'ncolor', 'Unknown')
                                    if isinstance(color, tuple):
                                        color = sum(color) / len(color)
                                    elif isinstance(color, np.ndarray):
                                        color = np.mean(color)
                                    elif isinstance(color, list):
                                        color = sum(color) / len(color)
                                    
                                    font_data.append({
                                        "Text": str(line_text),
                                        "Font Style": str(char.fontname),
                                        "Font Size": float(char.size),
                                        "Color": float(color),
                                        "Label": int(1)
                                    })
    except Exception as e:
        print("Error with pdfminer: {}".format(e))
        # Fallback to fitz (PyMuPDF) if pdfminer fails
        try:
            document = fitz.open(pdf_file)
            for page_number in range(len(document)):
                page = document.load_page(page_number)
                blocks = page.get_text('dict')['blocks']
                for block in blocks:
                    if block['type'] == 0:  # Text block
                        for line in block['lines']:
                            for span in line['spans']:
                                text = span['text']
                                font_style = span['font']
                                font_size = span['size']
                                color = span.get('color', 'Unknown')
                                
                                # Handle color extraction if color is a tuple or list
                                if isinstance(color, tuple):
                                    color = sum(color) / len(color)
                                elif isinstance(color, list):
                                    color = sum(color) / len(color)
                                
                                font_data.append({
                                    "Text": text,
                                    "Font Style": font_style,
                                    "Font Size": float(font_size),
                                    "Color": float(color),
                                    "Label": int(1)
                                })
        except Exception as e:
            print("Error with fitz (PyMuPDF): {}".format(e))
    
    return font_data

def extract_image_count(pdf_file):
    try:
        document = fitz.open(pdf_file)
        image_count = 0
        for page_num in range(len(document)):
            page = document[page_num]
            image_count += len(page.get_images(full=True))
        return image_count
    except Exception as e:
        print("Error counting images in {}: {}".format(pdf_file, e))
        return 0

def extract_font_information_with_metadata_and_images(pdf_file):
    metadata = extract_metadata(pdf_file)
    producer = str(metadata.get('producer', 'Unknown'))
    font_data = extract_font_information(pdf_file)
    image_count = extract_image_count(pdf_file)
    for entry in font_data:
        entry['Producer'] = producer
        entry['Image Count'] = image_count
    return font_data

def prepare_data_for_prediction(features):
    df = pd.DataFrame(features)
    feature_order = ["Font Style", "Font Size", "Color", "Producer", "Image Count"]
    for col in feature_order:
        if col not in df.columns:
            df[col] = np.nan
    df = df[feature_order]
    df["Font Style"] = df["Font Style"].astype(str)
    df["Producer"] = df["Producer"].astype(str)
    df.fillna({
        "Font Style": "Unknown",
        "Producer": "Unknown",
        "Font Size": 0,
        "Color": 0,
        "Image Count": 0
    }, inplace=True)
    return df
