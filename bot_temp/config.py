"""
FXAlexG Bot Configuration — v3.3 (AI-Powered Institutional Target Mode)
"""

TELEGRAM_TOKEN   = "REDACTED"
TELEGRAM_CHAT_ID = None  # Auto-discovered via /start or loaded from chat_id.json

# MT5 Bridge URL
BRIDGE_URL = "http://localhost:5001"

# --- MT5 Account Profiles ---
ACCOUNTS = {
    "demo": {
        "login":    00000000,
        "password": "",               # Uses saved session in MT5 terminal
        "server":   "REDACTED",
        "label":    "Demo (Trial)",
    },
    "real": {
        "login":    00000000,
        "server":   "REDACTED",
        "label":    "Real (Live)",
    },
}
ACTIVE_ACCOUNT = "demo"  # Default fallback; overwritten by active_account.json

# Pairs to scan (Includes Gold XAUUSDm for high volatility & faster profit)
SYMBOLS = ["EURUSDm", "GBPUSDm", "USDJPYm", "AUDUSDm", "USDCADm", "EURJPYm", "GBPJPYm", "BTCUSDm", "ETHUSDm", "XAUUSDm", "SOLUSDm", "XRPUSDm", "LTCUSDm"]

# --- High-Growth Lot Size & Risk Engine ---
# Targets $3.50 - $5.00 risk per trade to yield $10.00+ on winning trades
USE_FIXED_LOT   = False  
RISK_PERCENT    = 7.5    # 7.5% of balance (or minimum $3.50) to deliver $10+ profit per win
FIXED_LOT       = 0.01   # Fallback lot size if calculation fails

MIN_RISK_USD    = 1.50   # Floor: risk at least $1.50 to protect micro accounts
MAX_RISK_PCT    = 10.0   # Hard safety cap: never risk more than 10% on a single trade
MAX_RISK_USD    = 15.0   # Hard dollar cap
MIN_BALANCE     = 5.0    # USD — bot pauses if balance falls below this

# Trade Frequency & Concurrency
MAX_TRADES_DAY       = 4
MAX_TRADES_KILL_ZONE = 2
MAX_CONCURRENT       = 2
NEWS_LOOKOUT_MINS    = 30 # Skip entry if high-impact news within 30 min

# --- Take Profit, Risk-Reward & Trailing Stop ---
MIN_RR            = 2.0   # Minimum RR ratio required to accept a setup
TP1_RR            = 1.0   # Take 50% partial profit at 1:1.0 RR (banks quick cash & moves SL to BE)
TP2_RR            = 3.0   # Extended Final Take Profit target at 1:3.0 RR (Yields $10+ on full TP)
PARTIAL_PCT       = 0.5   # Close 50% of position at TP1
USE_TRAILING_STOP = True  # Trail SL behind 15M EMA21 after TP1
TRAILING_STOP_BUFFER = 5  # Pips buffer

# Trade Lifecycle
MAX_TRADE_LIFESPAN_HOURS = 36 # Close trade if TP1 not hit within 36h

# --- Quality & Safety Filters ---
ADX_PERIOD     = 14    # ADX calculation period
ADX_MIN        = 20    # Minimum ADX for trend confirmation — skip ranging markets

COOLDOWN_HOURS = 24    # Skip same symbol for 24h after a loss (prevents revenge trades)

# SL Lookback (number of 4H candles to scan for swing structure)
CRYPTO_SL_LOOKBACK = 12   # 48 hours — deeper structure for volatile crypto
FOREX_SL_LOOKBACK  = 6    # 24 hours — standard for forex pairs
CRYPTO_ATR_BUFFER  = 0.5  # ATR multiplier for crypto SL padding
FOREX_ATR_BUFFER   = 0.2  # ATR multiplier for forex SL padding

# Entry Quality Gates
MIN_GRADE       = "A+"   # Base mechanical threshold
MIN_TF_SYNC     = 2      # Allows shorts/longs when D1+4H agree even if W1 is neutral/counter
MIN_TF_SYNC_KZ  = 2      # Allow 2/3 sync for Kill Zone 15M CHoCH entries

# --- AI Intelligence Engine (Dual-Provider: Gemini 2.5 Flash + OpenRouter) ---
AI_ENABLED               = True
GEMINI_API_KEY           = "REDACTED"
OPENROUTER_API_KEY       = "REDACTED"
AI_CONFIRMATION_REQUIRED = True   # AI evaluates all candidate setups before opening orders
AI_MIN_CONFIDENCE        = 70     # Minimum AI confidence (0-100) to approve trade
AI_UPGRADE_B_PLUS        = True   # AI can upgrade high-scoring B+ (80+) setups if confidence >= 85
AI_POST_TRADE_REVIEW     = True   # AI reviews won/lost trades for learning
AI_SESSION_PULSE         = True   # Macro pulse broadcast after scan

# Spread Thresholds (XAUUSDm set to 300 points for Exness 3-decimal gold: $0.30 normal spread)
NORMAL_SPREAD_POINTS = {
    "EURUSDm": 15,
    "GBPUSDm": 20,
    "USDJPYm": 20,
    "AUDUSDm": 15,
    "USDCADm": 20,
    "EURJPYm": 25,
    "GBPJPYm": 50,
    "XAUUSDm": 300,
    "BTCUSDm": 1400,
    "ETHUSDm": 140,
    "SOLUSDm": 6000,
    "XRPUSDm": 1000,
    "LTCUSDm": 180,
}
MAX_SPREAD_MULT = 3

# Strategy Parameters
AOI_TOLERANCE   = 0.0025 # 0.25% zone tolerance
AOI_MIN_TOUCHES = 2
SWING_WINDOW    = 3
PSYCH_PIP_TOL   = 10

# EMAs
EMA_FAST  = 9
EMA_SLOW  = 21
EMA_TREND = 200

# RSI Entry Bounds
RSI_LONG_MIN  = 32
RSI_LONG_MAX  = 68
RSI_SHORT_MIN = 32
RSI_SHORT_MAX = 68

# Scan Schedule (4H candle closes UTC)
SCAN_HOURS = [0, 4, 8, 12, 16, 20]

# Dry run mode (False = live execution)
DRY_RUN = False

# Weekend analysis
WEEKEND_ANALYSIS_HOUR = 8
