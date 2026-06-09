import logging
import httpx
from fastapi import APIRouter, HTTPException, Query, status
from app.core.config import settings

logger = logging.getLogger("hospitals_api")

router = APIRouter(prefix="/hospitals", tags=["hospitals"])

# Fallback mock data when API key is not configured
MOCK_HOSPITALS = {
    "karnataka": [
        {
            "name": "Manipal Hospital",
            "contact": "+91 80 2222 1111",
            "address": "98, HAL Old Airport Rd, Bengaluru, Karnataka 560017",
        },
        {
            "name": "Narayana Health City",
            "contact": "+91 80 7122 2222",
            "address": "258/A, Bommasandra Industrial Area, Bengaluru, Karnataka 560099",
        },
        {
            "name": "Victoria Hospital",
            "contact": "+91 80 2670 1150",
            "address": "Fort Rd, New Tharagupet, Bengaluru, Karnataka 560002",
        },
    ],
    "maharashtra": [
        {
            "name": "Lilavati Hospital",
            "contact": "+91 22 2656 7777",
            "address": "A-791, Bandra Reclamation, Mumbai, Maharashtra 400050",
        },
        {
            "name": "KEM Hospital",
            "contact": "+91 22 2410 7000",
            "address": "Acharya Donde Marg, Parel, Mumbai, Maharashtra 400012",
        },
    ],
    "tamil nadu": [
        {
            "name": "Apollo Hospital Chennai",
            "contact": "+91 44 2829 3333",
            "address": "21, Greams Lane, Off Greams Road, Chennai, Tamil Nadu 600006",
        },
        {
            "name": "Government General Hospital",
            "contact": "+91 44 2530 5000",
            "address": "Park Town, Chennai, Tamil Nadu 600003",
        },
    ],
    "delhi": [
        {
            "name": "AIIMS Delhi",
            "contact": "+91 11 2658 8500",
            "address": "Sri Aurobindo Marg, Ansari Nagar, New Delhi, Delhi 110029",
        },
        {
            "name": "Safdarjung Hospital",
            "contact": "+91 11 2673 0000",
            "address": "Safdarjung Hospital Rd, New Delhi, Delhi 110029",
        },
    ],
    "west bengal": [
        {
            "name": "SSKM Hospital (PG Hospital)",
            "contact": "+91 33 2223 9178",
            "address": "244, AJC Bose Rd, Kolkata, West Bengal 700020",
        },
    ],
}


@router.get("/nearby")
async def get_nearby_hospitals(
    state: str = Query(..., description="State name to search hospitals in")
):
    """
    Find hospitals in a given Indian state.
    Uses OGD API if API_SETU_KEY is configured, else returns curated mock data.
    """
    state_clean = state.strip()

    if not state_clean:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="State parameter is required."
        )

    # Live API path
    if settings.API_SETU_KEY:
        try:
            url = (
                f"https://api.data.gov.in/resource/98fa254e-c5f8-4910-a19b-4828939b477d"
                f"?api-key={settings.API_SETU_KEY}&format=json"
                f"&filters[state]={state_clean}"
            )
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(url)
                data = response.json()

            if not data.get("records"):
                return {
                    "state": state_clean,
                    "hospitals": [],
                    "message": f"No hospital records found for '{state_clean}'.",
                }

            hospitals = [
                {
                    "name": record.get("hospital_name", "Unknown"),
                    "contact": (
                        record.get("emergency_number")
                        or record.get("mobile")
                        or record.get("telephone")
                        or "N/A"
                    ),
                    "address": (
                        f"{record.get('address', '')}, "
                        f"{record.get('district', '')}, "
                        f"{record.get('state', '')}, "
                        f"PIN: {record.get('pincode', '')}"
                    ).strip(", "),
                }
                for record in data["records"]
            ]
            return {"state": state_clean, "hospitals": hospitals}

        except Exception as e:
            logger.error(f"OGD API error: {e}. Falling back to mock data.")

    # Fallback: mock data
    state_key = state_clean.lower()
    hospitals = MOCK_HOSPITALS.get(state_key, [])

    if not hospitals:
        # Try partial match
        for key, data in MOCK_HOSPITALS.items():
            if state_key in key or key in state_key:
                hospitals = data
                break

    return {
        "state": state_clean,
        "hospitals": hospitals,
        "note": "Showing curated hospital data. Configure API_SETU_KEY for live results.",
    }
