from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/auth", tags=["Auth"])

class LoginRequest(BaseModel):
    email: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str

# Mock: aceita qualquer credencial (suficiente para o desafio)
@router.post("/login", response_model=TokenResponse)
def login(request: LoginRequest):
    """
    Autenticação mockada. Qualquer e-mail/senha válida gera um token JWT.
    Em produção, substituir por verificação real + geração de JWT.
    """
    if "@" not in request.email:
        raise HTTPException(status_code=400, detail="E-mail inválido")
    return TokenResponse(access_token="mock_jwt_token_for_demo", token_type="bearer")