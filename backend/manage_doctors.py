"""Operator-only doctor approval after independently checking credentials.

Run from backend/: python manage_doctors.py approve doctor@example.com
There is intentionally no public API for granting doctor access.
"""
import argparse
from app.core.database import SessionLocal
from app.models.db_models import User


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['approve', 'revoke'])
    parser.add_argument('email')
    args = parser.parse_args()
    with SessionLocal() as db:
        user = db.query(User).filter(User.email == args.email.strip().lower()).first()
        if not user or user.role not in {'doctor', 'doctor_pending'}:
            parser.error('No doctor or pending doctor account with that email')
        user.role = 'doctor' if args.action == 'approve' else 'doctor_pending'
        db.commit()
        print('Doctor access approved.' if args.action == 'approve' else 'Doctor access revoked.')


if __name__ == '__main__':
    main()
