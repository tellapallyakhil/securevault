import io
import os
import re
from pathlib import Path
from PIL import Image

# 1. High-accuracy PDF Parser
try:
    import pypdf
    HAS_PYPDF = True
except ImportError:
    HAS_PYPDF = False

# 2. Modern ONNX Deep Learning OCR Engine (No external system binary required)
try:
    from rapidocr_onnxruntime import RapidOCR
    rapid_ocr = RapidOCR()
    HAS_RAPID_OCR = True
except Exception as e:
    rapid_ocr = None
    HAS_RAPID_OCR = False

# 3. Optional PyTesseract Fallback
try:
    import pytesseract
    tess_paths = [
        r"C:\Program Files\Tesseract-OCR\tesseract.exe",
        r"C:\Users\tella\AppData\Local\Tesseract-OCR\tesseract.exe",
    ]
    for p in tess_paths:
        if os.path.exists(p):
            pytesseract.pytesseract.tesseract_cmd = p
            break
    HAS_PYTESSERACT = True
except ImportError:
    HAS_PYTESSERACT = False

class OCRService:
    """
    Intelligent OCR & Document Text Extraction Service:
    - PDFs: Multi-page vector & stream text extraction via pypdf
    - Images: Deep learning text detection & recognition via RapidOCR (PP-OCR ONNX runtime)
    - Fallbacks: PyTesseract, metadata parsing, plain text decoding
    """

    @classmethod
    def extract_text_from_bytes(cls, file_bytes: bytes, filename: str) -> str:
        ext = Path(filename).suffix.lower()
        
        # 1. Plaintext or structured text files
        if ext in [".txt", ".csv", ".json", ".md", ".log", ".xml", ".html"]:
            try:
                return file_bytes.decode('utf-8', errors='ignore')
            except Exception:
                return ""

        # 2. PDF Documents (Resumes, Reports, Invoices, Contracts)
        if ext == ".pdf":
            extracted_text = ""
            if HAS_PYPDF:
                try:
                    reader = pypdf.PdfReader(io.BytesIO(file_bytes))
                    page_texts = []
                    for page_idx, page in enumerate(reader.pages):
                        text = page.extract_text()
                        if text and text.strip():
                            page_texts.append(text.strip())
                    if not page_texts:
                        # Scanned PDF fallback: extract embedded images and perform OCR
                        for page in reader.pages:
                            try:
                                for image_file in page.images:
                                    img_text = cls.extract_text_from_bytes(image_file.data, image_file.name)
                                    if img_text and img_text.strip():
                                        page_texts.append(img_text.strip())
                            except Exception:
                                pass
                    if page_texts:
                        extracted_text = "\n\n".join(page_texts)
                except Exception as pdf_err:
                    print(f"pypdf extraction warning for {filename}: {pdf_err}")

            if extracted_text.strip():
                return extracted_text.strip()

            # Fallback regex scanner if pypdf was unable to find text stream
            try:
                decoded = file_bytes.decode('latin-1', errors='ignore')
                stream_texts = re.findall(r'\((.*?)\)\s*Tj', decoded)
                if stream_texts:
                    return " ".join(stream_texts).strip()
            except Exception:
                pass

            return ""

        # 3. Image Formats (Photos, Scans, Camera Shots, WhatsApp media)
        if ext in [".png", ".jpg", ".jpeg", ".bmp", ".tiff", ".webp"]:
            # Primary: RapidOCR Deep Learning ONNX engine
            if HAS_RAPID_OCR and rapid_ocr is not None:
                try:
                    result, _ = rapid_ocr(file_bytes)
                    if result:
                        text_lines = [box[1] for box in result if box and len(box) > 1 and box[1].strip()]
                        combined_text = "\n".join(text_lines).strip()
                        if combined_text:
                            return combined_text
                except Exception as ocr_err:
                    print(f"RapidOCR engine warning on {filename}: {ocr_err}")

            # Secondary: PyTesseract fallback
            if HAS_PYTESSERACT:
                try:
                    image = Image.open(io.BytesIO(file_bytes))
                    text = pytesseract.image_to_string(image)
                    if text.strip():
                        return text.strip()
                except Exception as tess_err:
                    print(f"Tesseract OCR warning on {filename}: {tess_err}")

            # Fallback with image metadata if no text could be recognized
            try:
                image = Image.open(io.BytesIO(file_bytes))
                return f"[Scanned Image {filename}: Size {image.size} Format {image.format}]"
            except Exception as e:
                return f"[Image {filename}: {str(e)}]"

        return f"[Document {filename}]"

ocr_service = OCRService()
