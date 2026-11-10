"""Check configured AI credentials without sending patient information."""
from app.core.config import settings
from app.core.gemini import generate_health_answer, GeminiUnavailable


def main():
    if not settings.gemini_api_key:
        print('AI is not configured. Set GOOGLE_AI_API_KEY in backend/.env and run this check again.')
        return 1
    try:
        generate_health_answer('Return a short greeting in the answer field. This is a connection test with no patient data.')
    except GeminiUnavailable as error:
        print(f'AI connection failed: {error.reason}. Check the provider key, model access and quota.')
        return 1
    print(f'AI connection verified with {settings.GEMINI_MODEL}.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
