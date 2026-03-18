#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// WiFi credentials
const char* ssid = "your_wifi_ssid";
const char* password = "your_wifi_password";

// API URL
const char* url = "https://production.dataviz.cnn.io/index/fearandgreed/graphdata";

// Display settings
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
#define SCREEN_ADDRESS 0x3C

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Update interval (12 hours in milliseconds)
const unsigned long UPDATE_INTERVAL = 12 * 60 * 60 * 1000;
unsigned long lastUpdate = 0;

void setup() {
  Serial.begin(115200);
  
  // Initialize display
  if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;);
  }
  
  // Connect to WiFi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected to WiFi");
  
  // Initial display setup
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0,0);
  display.println("Fear & Greed");
  display.println("Connecting...");
  display.display();
}

void updateDisplay(int score, const char* rating, const char* date) {
  display.clearDisplay();
  display.setCursor(0,0);
  
  // Title
  display.setTextSize(1);
  display.println("Fear & Greed Index");
  
  // Score
  display.setTextSize(2);
  display.print("Score: ");
  display.println(score);
  
  // Rating
  display.setTextSize(1);
  display.print("Rating: ");
  display.println(rating);
  
  // Date
  display.print("Date: ");
  display.println(date);
  
  display.display();
}

void fetchData() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(url);
    
    // Add headers to mimic a browser
    http.addHeader("User-Agent", "Mozilla/5.0");
    http.addHeader("Accept", "application/json");
    
    int httpCode = http.GET();
    
    if (httpCode > 0) {
      String payload = http.getString();
      
      // Parse JSON
      StaticJsonDocument<1024> doc;
      DeserializationError error = deserializeJson(doc, payload);
      
      if (!error) {
        // Extract data
        int score = doc["fear_and_greed"]["score"];
        const char* rating = doc["fear_and_greed"]["rating"];
        const char* timestamp = doc["fear_and_greed"]["timestamp"];
        
        // Extract just the date part from timestamp
        String date = String(timestamp).substring(0, 10);
        
        // Update display
        updateDisplay(score, rating, date.c_str());
        
        // Print to Serial for debugging
        Serial.print("Score: ");
        Serial.println(score);
        Serial.print("Rating: ");
        Serial.println(rating);
        Serial.print("Date: ");
        Serial.println(date);
      } else {
        Serial.println("JSON parsing failed");
      }
    } else {
      Serial.println("HTTP request failed");
    }
    
    http.end();
  } else {
    Serial.println("WiFi not connected");
  }
}

void loop() {
  unsigned long currentMillis = millis();
  
  // Check if it's time to update
  if (currentMillis - lastUpdate >= UPDATE_INTERVAL) {
    fetchData();
    lastUpdate = currentMillis;
  }
  
  // Small delay to prevent watchdog timer issues
  delay(1000);
} 