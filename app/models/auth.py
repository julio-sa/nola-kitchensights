from pydantic import BaseModel

class LoginRequest(BaseModel):
    email: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_name: str = "Maria"
    stores: list = [1, 2, 3]  # Maria tem 3 lojas