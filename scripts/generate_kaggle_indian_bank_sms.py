#!/usr/bin/env python3
"""
Generate a synthetic Indian bank SMS dataset for Kaggle / research.
Rows mix realistic templates; amounts and refs are fictional. Expand with real
redacted SMS from your inbox for production-quality models.

Outputs (under money_lens/data/):
  - kaggle_indian_bank_sms_dataset.jsonl   (recommended for NLP / multiline)
  - kaggle_indian_bank_sms_dataset.csv     (single-line raw_sms for spreadsheet tools)
"""

from __future__ import annotations

import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_JSONL = ROOT / "data" / "kaggle_indian_bank_sms_dataset.jsonl"
OUT_CSV = ROOT / "data" / "kaggle_indian_bank_sms_dataset.csv"


def rows():
    """Yield dict rows with consistent schema."""
    rid = 0

    def add(**kw):
        nonlocal rid
        rid += 1
        base = {
            "id": f"syn_{rid:04d}",
            "country": "IN",
            "currency": "INR",
            "language": "en",
        }
        base.update(kw)
        return base

    # --- Axis (UPI/P2M style + variants) ---
    yield add(
        bank="Axis",
        channel="UPI_P2M",
        raw_sms="INR 33.00 debited\nA/c no. XX5089\n09-04-26, 08:08:55\nUPI/P2M/609955063377/ROPPEN TRANSPORTATI\nNot you? SMS BLOCKUPI Cust ID to 919951860002\nAxis Bank",
        amount=33.0,
        txn_type="debit",
        merchant="ROPPEN TRANSPORTATI",
        account_last4="5089",
        is_financial_transaction=1,
        label_category="upi_debit",
    )
    yield add(
        bank="Axis",
        channel="UPI_P2M",
        raw_sms="INR 309.28 debited\nA/c no. XX5089\nUPI/P2M/153547358418/ZOMATO LIMITED\nNot you? SMS BLOCKUPI Cust ID to 919951860002",
        amount=309.28,
        txn_type="debit",
        merchant="ZOMATO LIMITED",
        account_last4="5089",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- SBI ---
    yield add(
        bank="SBI",
        channel="UPI",
        raw_sms="Dear UPI user A/C X4707 debited by 40.00 on date 09Apr26 trf to Mr Muthukumar R Refno 609914775933 If not u? call-1800111109-SBI",
        amount=40.0,
        txn_type="debit",
        merchant="Muthukumar R",
        account_last4="4707",
        is_financial_transaction=1,
        label_category="upi_debit",
    )
    yield add(
        bank="SBI",
        channel="NEFT",
        raw_sms="Acct XX5678 credited with Rs 25,000.00 on 05-Apr-26 from NEFT HDFCBANK0001234-SBI",
        amount=25000.0,
        txn_type="credit",
        merchant="NEFT_INCOMING",
        account_last4="5678",
        is_financial_transaction=1,
        label_category="neft_credit",
    )

    # --- HDFC ---
    yield add(
        bank="HDFC",
        channel="CARD",
        raw_sms="Rs.1,250.50 debited from HDFC Bank Card 5XX9012 to AMAZON PAY on 12-Apr-26. Avl bal Rs 43210.00",
        amount=1250.5,
        txn_type="debit",
        merchant="AMAZON PAY",
        account_last4="9012",
        is_financial_transaction=1,
        label_category="card_debit",
    )
    yield add(
        bank="HDFC",
        channel="UPI",
        raw_sms="Sent Rs. 89.00 from HDFC Bank A/c **7788 to swiggy.in@ybl on 11-04-26. Ref 912345678901",
        amount=89.0,
        txn_type="debit",
        merchant="swiggy.in@ybl",
        account_last4="7788",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- ICICI ---
    yield add(
        bank="ICICI",
        channel="UPI",
        raw_sms="ICICI Bank Acct XX1234 debited for INR 499.00 on 10-Apr-26. Info: BIGBASKET VPA bigbasket@icici Ref 887766554433",
        amount=499.0,
        txn_type="debit",
        merchant="BIGBASKET",
        account_last4="1234",
        is_financial_transaction=1,
        label_category="upi_debit",
    )
    yield add(
        bank="ICICI",
        channel="IMPS",
        raw_sms="Your ICICI Bank A/c XX9988 is credited with Rs. 15000.00 on 01-Apr-26 by IMPS from JOHN D Ref IMPS123456789",
        amount=15000.0,
        txn_type="credit",
        merchant="JOHN D",
        account_last4="9988",
        is_financial_transaction=1,
        label_category="imps_credit",
    )

    # --- Kotak ---
    yield add(
        bank="Kotak",
        channel="UPI",
        raw_sms="INR 175.00 debited from Kotak Bank A/c **5566 on 08-04-26 for UPI txn to zomato@paytm Ref 445566778899",
        amount=175.0,
        txn_type="debit",
        merchant="zomato@paytm",
        account_last4="5566",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Yes Bank ---
    yield add(
        bank="Yes Bank",
        channel="UPI",
        raw_sms="YES BANK: INR 2,100.00 debited from A/c XXXX2211 towards UPI-PHONEPE PAYMENT Refno 334455667788 on 07Apr26",
        amount=2100.0,
        txn_type="debit",
        merchant="PHONEPE PAYMENT",
        account_last4="2211",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- IndusInd ---
    yield add(
        bank="IndusInd",
        channel="CARD",
        raw_sms="IndusInd Bank: Rs 650.00 spent on your Card XX3344 at INOX LEISURE on 06-04-26. Avl Lmt Rs 98000",
        amount=650.0,
        txn_type="debit",
        merchant="INOX LEISURE",
        account_last4="3344",
        is_financial_transaction=1,
        label_category="card_debit",
    )

    # --- PNB ---
    yield add(
        bank="PNB",
        channel="UPI",
        raw_sms="PNB: A/c *4455 debited by Rs 120.00 on 05-04-26 UPI/DR/987654321098/ZEPTO Ref UPIPNB998877",
        amount=120.0,
        txn_type="debit",
        merchant="ZEPTO",
        account_last4="4455",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- BOB ---
    yield add(
        bank="BOB",
        channel="NEFT",
        raw_sms="Bank of Baroda: Your A/c XX8877 credited with Rs 8,500.00 on 04-04-26 thru NEFT from ACME CORP Ref NEFTBOB112233",
        amount=8500.0,
        txn_type="credit",
        merchant="ACME CORP",
        account_last4="8877",
        is_financial_transaction=1,
        label_category="neft_credit",
    )

    # --- Canara ---
    yield add(
        bank="Canara",
        channel="UPI",
        raw_sms="CANARA BANK: Rs.55.00 debited from A/c XX6655 towards UPI payment to irctc@axis Ref 223344556677 on 03Apr26",
        amount=55.0,
        txn_type="debit",
        merchant="irctc@axis",
        account_last4="6655",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Union Bank ---
    yield add(
        bank="Union Bank",
        channel="ATM",
        raw_sms="Union Bank of India: Cash withdrawal of Rs 2000.00 from A/c **4433 at ATM ID UBIN0001234 on 02-04-26",
        amount=2000.0,
        txn_type="debit",
        merchant="ATM_WITHDRAWAL",
        account_last4="4433",
        is_financial_transaction=1,
        label_category="atm_debit",
    )

    # --- IDFC First ---
    yield add(
        bank="IDFC First",
        channel="UPI",
        raw_sms="IDFC FIRST Bank: INR 320.00 debited from A/c XX1199 for UPI to merchant@okhdfcbank Ref 556677889900 on 01Apr26",
        amount=320.0,
        txn_type="debit",
        merchant="merchant@okhdfcbank",
        account_last4="1199",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Federal ---
    yield add(
        bank="Federal",
        channel="UPI",
        raw_sms="Federal Bank: Rs 45.00 debited from A/c **7781 UPI txn to googlepay@okaxis Ref 667788990011 dt 31-Mar-26",
        amount=45.0,
        txn_type="debit",
        merchant="googlepay@okaxis",
        account_last4="7781",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- RBL ---
    yield add(
        bank="RBL",
        channel="CARD",
        raw_sms="RBL Bank: Transaction of Rs 1299.00 on your RBL Card XX0022 at FLIPKART on 30-03-26",
        amount=1299.0,
        txn_type="debit",
        merchant="FLIPKART",
        account_last4="0022",
        is_financial_transaction=1,
        label_category="card_debit",
    )

    # --- AU Small Finance ---
    yield add(
        bank="AU Bank",
        channel="UPI",
        raw_sms="AU SFB: INR 500.00 debited from A/c XX3344 via UPI to paytmqr281@paytm Ref 445566778899 on 29Mar26",
        amount=500.0,
        txn_type="debit",
        merchant="paytmqr281@paytm",
        account_last4="3344",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Indian Bank ---
    yield add(
        bank="Indian Bank",
        channel="UPI",
        raw_sms="INDIAN BANK: Your A/c XX5566 is debited for Rs 75.00 on 28-03-26 UPI to billdesk@hdfcbank Ref 998877665544",
        amount=75.0,
        txn_type="debit",
        merchant="billdesk@hdfcbank",
        account_last4="5566",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Bank of India ---
    yield add(
        bank="Bank of India",
        channel="NEFT",
        raw_sms="BOI: Acct XX8877 credited Rs 4200.00 on 27-Mar-26 NEFT from RAHUL KUMAR Ref NEFTBOI887766",
        amount=4200.0,
        txn_type="credit",
        merchant="RAHUL KUMAR",
        account_last4="8877",
        is_financial_transaction=1,
        label_category="neft_credit",
    )

    # --- Central Bank ---
    yield add(
        bank="Central Bank of India",
        channel="UPI",
        raw_sms="CBI: Rs 30.00 debited from A/c **2233 UPI P2M to NPCI*uber on 26-03-26 Ref UPI223344556677",
        amount=30.0,
        txn_type="debit",
        merchant="NPCI*uber",
        account_last4="2233",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- UCO ---
    yield add(
        bank="UCO Bank",
        channel="UPI",
        raw_sms="UCO BANK: A/c XX4411 debited by INR 220.00 on 25Mar26 UPI to blinkit@ybl Ref 334455667788",
        amount=220.0,
        txn_type="debit",
        merchant="blinkit@ybl",
        account_last4="4411",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- DBS India ---
    yield add(
        bank="DBS",
        channel="UPI",
        raw_sms="DBS: INR 99.00 debited from Savings XX9900 on 24-03-26. Payee: NETFLIX.COM UPI Ref 887766554433",
        amount=99.0,
        txn_type="debit",
        merchant="NETFLIX.COM",
        account_last4="9900",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- HSBC India ---
    yield add(
        bank="HSBC",
        channel="CARD",
        raw_sms="HSBC IN: Rs 3,450.00 charged to your Credit Card XX1122 at RELIANCE SMART on 23-Mar-26",
        amount=3450.0,
        txn_type="debit",
        merchant="RELIANCE SMART",
        account_last4="1122",
        is_financial_transaction=1,
        label_category="card_debit",
    )

    # --- Bandhan ---
    yield add(
        bank="Bandhan Bank",
        channel="UPI",
        raw_sms="Bandhan Bank: Rs 15.00 debited from A/c **6677 UPI to npci*metro on 22-03-26 Ref BBUPI998877",
        amount=15.0,
        txn_type="debit",
        merchant="npci*metro",
        account_last4="6677",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Karnataka Bank ---
    yield add(
        bank="Karnataka Bank",
        channel="UPI",
        raw_sms="KBL: INR 180.00 debited from SB A/c XX5544 for UPI to swiggy@ibl Ref 223344556677 dt 21Mar26",
        amount=180.0,
        txn_type="debit",
        merchant="swiggy@ibl",
        account_last4="5544",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- South Indian Bank ---
    yield add(
        bank="South Indian Bank",
        channel="UPI",
        raw_sms="SIB: Your A/c XX3322 debited Rs 950.00 on 20-03-26 UPI P2M to BOOKMYSHOW Ref SIBUPI445566",
        amount=950.0,
        txn_type="debit",
        merchant="BOOKMYSHOW",
        account_last4="3322",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Tamilnad Mercantile ---
    yield add(
        bank="TMB",
        channel="UPI",
        raw_sms="TMB: Rs 60.00 debited from A/c **8877 UPI to phonepe@ybl Ref TMBUPI7788990011 on 19Mar26",
        amount=60.0,
        txn_type="debit",
        merchant="phonepe@ybl",
        account_last4="8877",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- City Union ---
    yield add(
        bank="City Union Bank",
        channel="UPI",
        raw_sms="CUB: INR 240.00 debited from A/c XX6655 towards UPI txn to ola@ybl Ref CUBUPI3344556677",
        amount=240.0,
        txn_type="debit",
        merchant="ola@ybl",
        account_last4="6655",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Paytm Payments Bank ---
    yield add(
        bank="Paytm Payments Bank",
        channel="UPI",
        raw_sms="Paytm Payments Bank: Rs 35.00 debited from PPBL A/c **2211 for UPI to merchant@paytm Ref PPBL9988776655",
        amount=35.0,
        txn_type="debit",
        merchant="merchant@paytm",
        account_last4="2211",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Airtel Payments Bank ---
    yield add(
        bank="Airtel Payments Bank",
        channel="UPI",
        raw_sms="Airtel Payments Bank: INR 49.00 debited for UPI recharge txn Ref AIRTELPAY112233 on 18-03-26",
        amount=49.0,
        txn_type="debit",
        merchant="UPI_RECHARGE",
        account_last4="",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Standard Chartered ---
    yield add(
        bank="Standard Chartered",
        channel="CARD",
        raw_sms="StanChart: Rs 2,899.00 debited on your Card XX5566 at CROMA on 17-Mar-26",
        amount=2899.0,
        txn_type="debit",
        merchant="CROMA",
        account_last4="5566",
        is_financial_transaction=1,
        label_category="card_debit",
    )

    # --- Citibank India style ---
    yield add(
        bank="Citibank",
        channel="CARD",
        raw_sms="CITI: INR 1250.00 spent on Citi Card ending 7788 at NYKAA on 16Mar26",
        amount=1250.0,
        txn_type="debit",
        merchant="NYKAA",
        account_last4="7788",
        is_financial_transaction=1,
        label_category="card_debit",
    )

    # --- Bajaj Finserv / co-brand style ---
    yield add(
        bank="RBL",
        channel="CARD",
        raw_sms="Bajaj Finserv RBL Card: Rs 599.00 transaction at AMAZON on 15-03-26 on card XX4433",
        amount=599.0,
        txn_type="debit",
        merchant="AMAZON",
        account_last4="4433",
        is_financial_transaction=1,
        label_category="card_debit",
    )

    # --- More HDFC variants ---
    yield add(
        bank="HDFC",
        channel="UPI",
        raw_sms="HDFC Bank: Rs.500.00 debited from your A/c **8899 towards UPI txn to CRED@ybl Ref 223344556677 on 14Apr26",
        amount=500.0,
        txn_type="debit",
        merchant="CRED@ybl",
        account_last4="8899",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- More ICICI credit ---
    yield add(
        bank="ICICI",
        channel="UPI",
        raw_sms="ICICI Bank: Your A/c XX6677 is credited for Rs. 1200.00 on 13-Apr-26 from googlepay@okaxis Ref 998877665544",
        amount=1200.0,
        txn_type="credit",
        merchant="googlepay@okaxis",
        account_last4="6677",
        is_financial_transaction=1,
        label_category="upi_credit",
    )

    # --- Kotak salary credit ---
    yield add(
        bank="Kotak",
        channel="NEFT",
        raw_sms="Kotak: INR 85000.00 credited to A/c **3344 on 12Apr26 from SALARY CREDIT ACME LTD Ref NEFTKOT998877",
        amount=85000.0,
        txn_type="credit",
        merchant="ACME LTD",
        account_last4="3344",
        is_financial_transaction=1,
        label_category="salary_credit",
    )

    # --- Axis credit interest ---
    yield add(
        bank="Axis",
        channel="INTEREST",
        raw_sms="Axis Bank: Rs 112.34 credited to A/c XX5089 towards interest for 01Jan26-31Mar26 Ref INTAXIS887766",
        amount=112.34,
        txn_type="credit",
        merchant="INTEREST_CREDIT",
        account_last4="5089",
        is_financial_transaction=1,
        label_category="interest_credit",
    )

    # --- Negative / non-transaction ---
    yield add(
        bank="",
        channel="OTP",
        raw_sms="HDFC Bank: 482910 is your OTP for txn of Rs 5000.00. Do not share OTP with anyone.",
        amount=5000.0,
        txn_type="unknown",
        merchant="",
        account_last4="",
        is_financial_transaction=0,
        label_category="otp",
    )
    yield add(
        bank="",
        channel="PROMO",
        raw_sms="Flipkart: Flat 40% OFF on electronics! Use code SAVE40. Shop now. T&C apply.",
        amount=0.0,
        txn_type="unknown",
        merchant="",
        account_last4="",
        is_financial_transaction=0,
        label_category="promotional",
    )
    yield add(
        bank="SBI",
        channel="BALANCE",
        raw_sms="SBI: Your A/c XX5678 balance is Rs 12345.67 as on 10-Apr-26. For disputes call 1800112211",
        amount=0.0,
        txn_type="unknown",
        merchant="",
        account_last4="5678",
        is_financial_transaction=0,
        label_category="balance_enquiry",
    )
    yield add(
        bank="ICICI",
        channel="ALERT",
        raw_sms="ICICI Bank: Your registered mobile number was updated successfully on 09-Apr-26. If not you, call customer care.",
        amount=0.0,
        txn_type="unknown",
        merchant="",
        account_last4="",
        is_financial_transaction=0,
        label_category="service_alert",
    )

    # --- Jammu & Kashmir Bank ---
    yield add(
        bank="J&K Bank",
        channel="UPI",
        raw_sms="JK BANK: Rs 88.00 debited from A/c XX7722 UPI to qrcode@ybl Ref JKUPI556677 on 10Mar26",
        amount=88.0,
        txn_type="debit",
        merchant="qrcode@ybl",
        account_last4="7722",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Karur Vysya ---
    yield add(
        bank="KVB",
        channel="UPI",
        raw_sms="KVB: INR 155.00 debited from SB A/c **8899 towards UPI to dominos@ibl Ref KVBUPI334455",
        amount=155.0,
        txn_type="debit",
        merchant="dominos@ibl",
        account_last4="8899",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Dhanlaxmi ---
    yield add(
        bank="Dhanlaxmi Bank",
        channel="UPI",
        raw_sms="DLB: Your A/c XX4455 debited Rs 42.00 on 09Mar26 UPI txn to npci*rapido Ref DLBUPI887766",
        amount=42.0,
        txn_type="debit",
        merchant="npci*rapido",
        account_last4="4455",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Equitas SFB ---
    yield add(
        bank="Equitas SFB",
        channel="UPI",
        raw_sms="Equitas SFB: INR 199.00 debited from A/c **6677 UPI P2M to jiomart@paytm Ref EQTS998877",
        amount=199.0,
        txn_type="debit",
        merchant="jiomart@paytm",
        account_last4="6677",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Ujjivan SFB ---
    yield add(
        bank="Ujjivan SFB",
        channel="UPI",
        raw_sms="Ujjivan SFB: Rs 25.00 debited from A/c XX3344 for UPI to npci*fastag Ref UJVN112233",
        amount=25.0,
        txn_type="debit",
        merchant="npci*fastag",
        account_last4="3344",
        is_financial_transaction=1,
        label_category="upi_debit",
    )

    # --- Extra volume: parametric variations (synthetic) ---
    banks_spin = [
        ("Axis", "Axis Bank"),
        ("HDFC", "HDFC Bank"),
        ("ICICI", "ICICI Bank"),
        ("SBI", "SBI"),
        ("Kotak", "Kotak Bank"),
        ("PNB", "PNB"),
        ("BOB", "Bank of Baroda"),
        ("Canara", "CANARA BANK"),
        ("Union Bank", "Union Bank of India"),
        ("Yes Bank", "YES BANK"),
    ]
    for i in range(1, 151):
        amt = round(10.0 + (i * 17.37) % 75000, 2)
        a4 = f"{(1000 + i * 137) % 10000:04d}"
        bank, footer = banks_spin[i % len(banks_spin)]
        if bank == "Axis":
            raw = (
                f"INR {amt:.2f} debited\nA/c no. XX{a4}\n"
                f"UPI/P2M/{900000000 + i}/TESTMERCHANT{i}\nNot you? SMS BLOCKUPI\n{footer}"
            )
            ch = "UPI_P2M"
        elif bank == "HDFC":
            raw = f"{footer}: Rs.{amt:.2f} debited from A/c **{a4} to SHOP{i} on 01-Apr-26"
            ch = "UPI"
        elif bank == "SBI":
            raw = (
                f"Dear UPI user A/C X{a4} debited by {amt:.2f} on date {i % 28 + 1:02d}Apr26 "
                f"trf to Mr TESTPAYEE{i} Refno {600000000 + i} {footer}"
            )
            ch = "UPI"
        elif bank in ("PNB", "BOB", "Canara", "Union Bank", "Yes Bank"):
            raw = (
                f"{footer}: A/c **{a4} debited Rs {amt:.2f} on 03-Apr-26 "
                f"UPI to MERCHANT{i}@ybl Ref {300000000 + i}"
            )
            ch = "UPI"
        else:
            raw = f"{footer}: Acct XX{a4} debited for INR {amt:.2f} on 02-Apr-26 Info: CAFE{i} Ref {200000 + i}"
            ch = "UPI"
        if bank == "Axis":
            merch = f"TESTMERCHANT{i}"
        elif bank == "HDFC":
            merch = f"SHOP{i}"
        elif bank == "SBI":
            merch = f"TESTPAYEE{i}"
        elif bank in ("PNB", "BOB", "Canara", "Union Bank", "Yes Bank"):
            merch = f"MERCHANT{i}@ybl"
        else:
            merch = f"CAFE{i}"
        yield add(
            bank=bank,
            channel=ch,
            raw_sms=raw,
            amount=amt,
            txn_type="debit",
            merchant=merch,
            account_last4=a4,
            is_financial_transaction=1,
            label_category="synthetic_spin",
        )


def main():
    OUT_JSONL.parent.mkdir(parents=True, exist_ok=True)
    all_rows = list(rows())
    with OUT_JSONL.open("w", encoding="utf-8") as f:
        for r in all_rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    # CSV: flatten raw_sms (replace newlines)
    fieldnames = [
        "id",
        "country",
        "currency",
        "language",
        "bank",
        "channel",
        "raw_sms",
        "amount",
        "txn_type",
        "merchant",
        "account_last4",
        "is_financial_transaction",
        "label_category",
    ]
    with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for r in all_rows:
            row = dict(r)
            row["raw_sms"] = re.sub(r"[\r\n]+", " / ", row["raw_sms"].strip())
            w.writerow(row)

    print(f"Wrote {OUT_JSONL} ({len(all_rows)} rows)")
    print(f"Wrote {OUT_CSV} ({len(all_rows)} rows)")


if __name__ == "__main__":
    main()
