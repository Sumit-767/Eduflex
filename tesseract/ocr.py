import os
from pdfminer.high_level import extract_text
from pdfminer.pdfpage import PDFPage
from pdfminer.pdfinterp import PDFResourceManager, PDFPageInterpreter
from pdfminer.pdfdevice import PDFDevice
from pdfminer.converter import PDFPageAggregator
from pdfminer.layout import LAParams, LTTextBox, LTTextLine, LTChar
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
import pandas as pd

def extract_font_information(pdf_file):
    fonts = []
    with open(pdf_file, 'rb') as file:
        rsrcmgr = PDFResourceManager()
        laparams = LAParams()
        device = PDFPageAggregator(rsrcmgr, laparams=laparams)
        interpreter = PDFPageInterpreter(rsrcmgr, device)
        for page in PDFPage.get_pages(file):
            interpreter.process_page(page)
            layout = device.get_result()
            for element in layout:
                if isinstance(element, LTTextBox) or isinstance(element, LTTextLine):
                    for text_line in element:
                        for char in text_line:
                            if isinstance(char, LTChar):
                                fonts.append((char.get_text(), char.fontname, char.size))
    return fonts

def load_data(data_dir):
    data = []
    labels = []
    for label in ["genuine", "fake"]:
        label_dir = os.path.join(data_dir, label)
        for file_name in os.listdir(label_dir):
            if file_name.endswith('.pdf'):
                file_path = os.path.join(label_dir, file_name)
                fonts = extract_font_information(file_path)
                font_data = ' '.join([f"{font[1]}_{font[2]}" for font in fonts])  # Combine font name and size
                data.append(font_data)
                labels.append(label)
    return data, labels

def train_model(data, labels):
    vectorizer = CountVectorizer()
    X = vectorizer.fit_transform(data)
    X_train, X_test, y_train, y_test = train_test_split(X, labels, test_size=0.2, random_state=42)
    
    model = RandomForestClassifier()
    model.fit(X_train, y_train)
    
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    print(f"Model accuracy: {accuracy * 100:.2f}%")
    
    return model, vectorizer

def predict_certificate(model, vectorizer, pdf_file):
    fonts = extract_font_information(pdf_file)
    font_data = ' '.join([f"{font[1]}_{font[2]}" for font in fonts])
    X = vectorizer.transform([font_data])
    prediction = model.predict(X)
    return prediction[0]

# Example usage
data_dir = "certificates_dataset"
data, labels = load_data(data_dir)
model, vectorizer = train_model(data, labels)

pdf_file = "your_certificate.pdf"
prediction = predict_certificate(model, vectorizer, pdf_file)
print(f"The certificate is {prediction}")
