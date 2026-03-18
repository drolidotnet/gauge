import requests
from datetime import datetime, timezone
import time
import csv
import os

URL = "https://production.dataviz.cnn.io/index/fearandgreed/graphdata"

# Add headers to mimic a browser request
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://www.cnn.com/',
    'Origin': 'https://www.cnn.com'
}

def fetch_score():
    r = requests.get(URL, headers=HEADERS)
    data = r.json()
    score = round(data["fear_and_greed"]["score"])
    rating = data["fear_and_greed"]["rating"]
    timestamp = data["fear_and_greed"]["timestamp"]
    # Also get historical data
    historical = data.get("fear_and_greed_historical", {}).get("data", [])
    return timestamp, score, rating, historical

def update_csv(timestamp, score, rating, historical, path="fng_log.csv"):
    # Read existing dates for quick lookup and get the last date
    existing_dates = set()
    last_date = None
    if os.path.exists(path):
        with open(path, 'r', newline='') as f:
            reader = csv.reader(f)
            rows = list(reader)
            if rows:  # If file is not empty
                last_date = rows[-1][0]  # Get the last date
            existing_dates = {row[0] for row in rows}
    
    # Prepare new data
    new_rows = []
    
    # Add historical data
    for entry in historical:
        # Convert timestamp to date only (YYYY-MM-DD)
        ts = datetime.fromtimestamp(entry["x"] / 1000, timezone.utc).strftime('%Y-%m-%d')
        if ts not in existing_dates:  # Only add if date doesn't exist
            new_rows.append([ts, str(round(entry["y"])), entry["rating"]])
            existing_dates.add(ts)  # Add to set to prevent duplicates within new data
    
    # Add latest data (convert ISO timestamp to date)
    date_only = datetime.fromisoformat(timestamp.replace('Z', '+00:00')).strftime('%Y-%m-%d')
    if date_only not in existing_dates:  # Only add if date doesn't exist
        new_rows.append([date_only, str(score), rating])
    
    # Sort new rows by date
    new_rows.sort(key=lambda x: x[0])
    
    # If we have new data, append it to the file
    if new_rows:
        # If we have a last_date, verify new data is after it
        if last_date and new_rows[0][0] <= last_date:
            # If new data is not after last_date, we need to resort the entire file
            with open(path, 'r', newline='') as f:
                reader = csv.reader(f)
                all_rows = list(reader) + new_rows
                all_rows.sort(key=lambda x: x[0])
            
            with open(path, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerows(all_rows)
        else:
            # If new data is after last_date, we can safely append
            with open(path, 'a', newline='') as f:
                writer = csv.writer(f)
                writer.writerows(new_rows)
    
    # Clear variables to help with memory management
    del existing_dates, new_rows, last_date

# Example polling loop
while True:
    try:
        ts, score, rating, historical = fetch_score()
        print(f"{ts} – Score: {score}, Rating: {rating}")
        update_csv(ts, score, rating, historical)
    except Exception as e:
        print("Error:", e)
    time.sleep(43200)  # run every 12 hours