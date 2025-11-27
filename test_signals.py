"""
Script de test - Simule l'envoi de signaux comme le ferait l'EA MT5
Utile pour tester le dashboard sans MT5
"""

import requests
import time
import random
from datetime import datetime

FLASK_URL = "http://localhost:5000"

def generate_signal(trend=None, momentum_shift=False):
    """Génère un signal simulé"""
    
    if trend is None:
        trend = random.choice(["BULLISH", "BEARISH"])
    
    # Prix de base simulé
    base_price = 0.88500 + random.uniform(-0.005, 0.005)
    spread = random.uniform(5, 15)
    
    signal = {
        "timestamp": datetime.now().isoformat(),
        "symbol": "USDCHF",
        "timeframe": "H1",
        "signal_type": "MOMENTUM_SHIFT" if momentum_shift else "NEW_BAR",
        "ha_open": base_price + random.uniform(-0.001, 0.001),
        "ha_high": base_price + random.uniform(0.001, 0.003),
        "ha_low": base_price - random.uniform(0.001, 0.003),
        "ha_close": base_price + random.uniform(-0.001, 0.001),
        "trend": trend,
        "momentum_shift": 1 if momentum_shift else 0,
        "bid": base_price,
        "ask": base_price + (spread * 0.00001),
        "spread": spread
    }
    
    return signal

def send_signal(signal):
    """Envoie un signal au serveur Flask"""
    try:
        response = requests.post(
            f"{FLASK_URL}/api/signal",
            json=signal,
            timeout=5
        )
        if response.status_code == 200:
            print(f"✅ Signal envoyé: {signal['trend']} | Momentum: {signal['momentum_shift']}")
            return True
        else:
            print(f"❌ Erreur: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("❌ Impossible de se connecter au serveur Flask")
        print("   Assurez-vous que le serveur est démarré (python app.py)")
        return False

def test_sequence():
    """Envoie une séquence de signaux pour tester"""
    
    print("=" * 50)
    print("Test du Crystal Heikin Flask Bridge")
    print("=" * 50)
    print()
    
    # Test de connexion
    print("1. Test de connexion...")
    signal = generate_signal("BULLISH")
    if not send_signal(signal):
        return
    
    print()
    print("2. Simulation de signaux (Ctrl+C pour arrêter)...")
    print()
    
    last_trend = "BULLISH"
    try:
        while True:
            # 20% de chance de momentum shift
            if random.random() < 0.2:
                new_trend = "BEARISH" if last_trend == "BULLISH" else "BULLISH"
                signal = generate_signal(new_trend, momentum_shift=True)
                last_trend = new_trend
            else:
                signal = generate_signal(last_trend)
            
            send_signal(signal)
            time.sleep(random.uniform(2, 5))
            
    except KeyboardInterrupt:
        print("\n\nTest arrêté.")

def send_single_signal():
    """Envoie un seul signal (pour tests rapides)"""
    signal = generate_signal("BULLISH", momentum_shift=True)
    send_signal(signal)

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--single":
        send_single_signal()
    else:
        test_sequence()
