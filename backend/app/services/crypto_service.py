import os
import base64
from typing import Tuple
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.argon2 import Argon2id
from cryptography.hazmat.backends import default_backend
from app.core.config import settings

class CryptoService:
    """
    AES-256-GCM Cryptographic Engine
    Zero-knowledge design: generates authenticated ciphertext with AEAD tag.
    Tamper detection is guaranteed by the 128-bit authentication tag.
    """
    
    SALT_SIZE = 16
    NONCE_SIZE = 12
    TAG_SIZE = 16
    KEY_SIZE = 32  # 256 bits

    @classmethod
    def derive_key(cls, user_secret: str, salt: bytes) -> bytes:
        """
        Derives an AES-256 key from a user secret / master password using Argon2id.
        """
        kdf = Argon2id(
            salt=salt,
            length=cls.KEY_SIZE,
            iterations=2,
            lanes=4,
            memory_cost=65536,
        )
        return kdf.derive(user_secret.encode('utf-8'))

    @classmethod
    def encrypt_bytes(cls, plaintext: bytes, user_secret: str = None) -> bytes:
        """
        Encrypts plaintext bytes using AES-256-GCM.
        Returns: salt (16) + nonce (12) + ciphertext_with_tag
        """
        secret = user_secret or settings.SECRET_KEY
        salt = os.urandom(cls.SALT_SIZE)
        key = cls.derive_key(secret, salt)
        
        nonce = os.urandom(cls.NONCE_SIZE)
        aesgcm = AESGCM(key)
        
        # AESGCM.encrypt appends 16-byte tag at the end of ciphertext
        ciphertext_with_tag = aesgcm.encrypt(nonce, plaintext, None)
        
        # Package: salt + nonce + ciphertext_with_tag
        return salt + nonce + ciphertext_with_tag

    @classmethod
    def decrypt_bytes(cls, encrypted_payload: bytes, user_secret: str = None) -> bytes:
        """
        Decrypts an AES-256-GCM encrypted payload.
        Verifies authentication tag and rejects tampered data.
        """
        secret = user_secret or settings.SECRET_KEY
        
        if len(encrypted_payload) < (cls.SALT_SIZE + cls.NONCE_SIZE + cls.TAG_SIZE):
            raise ValueError("Invalid encrypted payload size: corrupted data.")
            
        salt = encrypted_payload[:cls.SALT_SIZE]
        nonce = encrypted_payload[cls.SALT_SIZE:cls.SALT_SIZE + cls.NONCE_SIZE]
        ciphertext_with_tag = encrypted_payload[cls.SALT_SIZE + cls.NONCE_SIZE:]
        
        key = cls.derive_key(secret, salt)
        aesgcm = AESGCM(key)
        
        # Will raise cryptography.exceptions.InvalidTag if ciphertext or tag was tampered with
        return aesgcm.decrypt(nonce, ciphertext_with_tag, None)

    @classmethod
    def encrypt_text(cls, text: str, user_secret: str = None) -> str:
        encrypted_bytes = cls.encrypt_bytes(text.encode('utf-8'), user_secret)
        return base64.b64encode(encrypted_bytes).decode('utf-8')

    @classmethod
    def decrypt_text(cls, encoded_str: str, user_secret: str = None) -> str:
        encrypted_bytes = base64.b64decode(encoded_str.encode('utf-8'))
        decrypted_bytes = cls.decrypt_bytes(encrypted_bytes, user_secret)
        return decrypted_bytes.decode('utf-8')

crypto_service = CryptoService()
