# ⠓⠁⠏ HaptiBraille — Tactile Braille Haptic Translator

A real-time assistive technology web app engineered for **CodeDay** that translates text, speech, and quick emergency prompts into **physical Braille vibration pulses** for Deafblind individuals.

---

## 🌟 Why This Matters
Refreshable Braille displays cost between **$1,500 and $5,000+**, leaving millions of deafblind and severely visually/auditorily impaired people cut off from rapid communication. 

**HaptiBraille** utilizes the tactile vibration motor present inside everyday smartphones and smartwatches to deliver serialized Grade 1 Unified English Braille (UEB) pulses directly into the user's hand at **zero hardware cost**.

---

## 🚀 How to Run It Right Now

### Option 1: On Your PC / Laptop (Desktop Mode)
Open PowerShell or Command Prompt:

```powershell
cd C:\Users\MANISH\Desktop\games_creation\tactile_braille
node server.js
```
Then open your browser to:
👉 **[http://localhost:3000](http://localhost:3000)**

*(Note: On computers without a vibration motor, HaptiBraille automatically activates high-precision **sub-bass audio click synthesis**, so you can hear and test the exact haptic pulse rhythm!)*

---

### Option 2: Live on Your Android Phone (Hardware Motor Test)
1. Make sure your phone and laptop are connected to the same Wi-Fi network.
2. In your terminal, running `node server.js` will print your local IP address (e.g. `http://192.168.1.X:3000`).
3. Open that address in Chrome on your Android phone.
4. Press **"Transmit Tactile Pulses"** or tap any preset like **"HELP"** or **"YES"** — the phone's vibration motor will physically buzz each dot in your hand!

---

## 🧠 How the Tactile Encoding Works

Standard Braille is represented by a 6-dot matrix cell:
```
(1)  (4)
(2)  (5)
(3)  (6)
```

1. **Serialized Scanning ($1 \to 6$):** The app evaluates dots in standard sequence.
2. **Active Dot (Raised):** Triggers a defined vibration pulse (default: $90\text{ ms}$).
3. **Inactive Dot (Empty):** Leaves a silent gap (default: $70\text{ ms}$).
4. **Inter-Cell Pause:** A longer pause ($350\text{ ms}$) lets the reader feel the boundary between letters.
5. **Word Boundary:** A $500\text{ ms}+$ rest marks spaces between words.

---

## 🏆 Key Features for Hackathon Judges

1. **Full Grade 1 Unified English Braille (UEB) Matrix:**
   - Letters A–Z, numbers 0–9 (with automatic number sign `#` prefix), and punctuation marks (`. , ? !`).
2. **Real Haptic Engine + Dual Audio Simulator:**
   - Native `navigator.vibrate` hardware API.
   - Dual-mode sub-bass synthetic thumps so judges on Macs/PCs can experience the timing without a mobile device.
3. **Voice-to-Vibration (Speech-to-Text):**
   - Click the mic icon, say any word (e.g., *"WATER"* or *"STOP"*), and the phone immediately begins pulsing the Braille sequence.
4. **Alphabet Practice Matrix:**
   - Tap individual letters in the lower grid to feel their unique tactile signature.
5. **Interactive Fine-Tuning Controls:**
   - Adjust Dot Pulse Duration, Dot Gap, and Character Pause sliders to simulate beginner vs. advanced Braille reading speeds.
