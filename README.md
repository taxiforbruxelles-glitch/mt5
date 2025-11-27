# Crystal Heikin Ashi - Flask Bridge

Application Flask pour recevoir et visualiser les signaux de l'indicateur Crystal Heikin Ashi 3.05 depuis MetaTrader 5.

## 📁 Structure du projet

```
crystal_heikin_flask/
├── app.py                    # Application Flask principale
├── requirements.txt          # Dépendances Python
├── signals.db               # Base SQLite (créée automatiquement)
├── templates/
│   └── dashboard.html       # Interface web du dashboard
└── mt5/
    └── CrystalHeikin_FlaskBridge.mq5  # Expert Advisor MT5
```

## 🚀 Installation

### 1. Installer les dépendances Python

```bash
cd crystal_heikin_flask
pip install -r requirements.txt
```

### 2. Démarrer le serveur Flask

```bash
python app.py
```

Le serveur démarre sur `http://localhost:5000`

### 3. Configurer MetaTrader 5

#### A. Autoriser WebRequest

1. Ouvrir MT5
2. Aller dans **Outils → Options → Expert Advisors**
3. Cocher **Autoriser WebRequest pour les URL listées**
4. Ajouter: `http://localhost:5000`
5. Cliquer OK

#### B. Installer l'EA

1. Copier `CrystalHeikin_FlaskBridge.mq5` dans:
   ```
   C:\Users\[VOTRE_NOM]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Experts\
   ```
2. Dans MT5, ouvrir le Navigateur (Ctrl+N)
3. Clic droit sur **Experts** → **Actualiser**
4. Compiler l'EA (F7 dans MetaEditor)

#### C. Lancer l'EA

1. Ouvrir un graphique avec Crystal Heikin Ashi déjà actif
2. Glisser l'EA `CrystalHeikin_FlaskBridge` sur le graphique
3. Configurer les paramètres:
   - **FlaskServerURL**: `http://localhost:5000`
   - **IndicatorName**: `Market\Crystal Heikin Ashi` (ou le chemin exact)
   - **SendOnNewBar**: `true`
   - **EnableTrading**: `true` si vous voulez trader depuis Flask

4. Cliquer OK

## 🖥️ Utilisation du Dashboard

Ouvrir `http://localhost:5000` dans votre navigateur.

### Fonctionnalités:

- **Signal Actuel**: Affiche le dernier signal reçu (symbole, tendance, prix Heikin Ashi)
- **Momentum Shift**: S'illumine quand un changement de tendance est détecté
- **Statistiques 24h**: Compte les signaux bullish/bearish et les momentum shifts
- **Contrôle Trading**: Envoyer des ordres BUY/SELL directement à MT5
- **Historique**: Liste des derniers signaux reçus

## 🔧 API Endpoints

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/signal` | POST | Recevoir un signal de MT5 |
| `/api/trade` | POST | Envoyer une commande de trade |
| `/api/pending_trades` | GET | Récupérer les trades en attente |
| `/api/confirm_trade/<id>` | POST | Confirmer l'exécution d'un trade |
| `/api/signals/history` | GET | Historique des signaux |
| `/api/stats` | GET | Statistiques |

## 📡 Format des signaux

```json
{
    "timestamp": "2025-11-25 14:30:00",
    "symbol": "USDCHF",
    "timeframe": "H1",
    "signal_type": "MOMENTUM_SHIFT",
    "ha_open": 0.88456,
    "ha_high": 0.88512,
    "ha_low": 0.88423,
    "ha_close": 0.88498,
    "trend": "BULLISH",
    "momentum_shift": 1,
    "bid": 0.88495,
    "ask": 0.88502,
    "spread": 7.0
}
```

## ⚠️ Notes importantes

1. **L'indicateur Crystal Heikin Ashi est compilé (.ex5)** - On ne peut que lire ses buffers, pas le modifier

2. **Les buffers peuvent varier** - Si les valeurs ne sont pas correctes, il faudra peut-être ajuster les indices des buffers dans l'EA (0-4)

3. **WebRequest doit être autorisé** - Sans ça, l'EA ne peut pas communiquer avec Flask

4. **Trading** - Les ordres passés depuis Flask sont réels! Utilisez un compte démo pour tester.

## 🐛 Dépannage

### L'EA affiche "ERREUR: Impossible de charger l'indicateur"
- Vérifiez que Crystal Heikin Ashi est bien sur le graphique
- Vérifiez le chemin de l'indicateur dans les paramètres

### "ERREUR: URL non autorisée"
- Ajoutez `http://localhost:5000` dans Outils → Options → Expert Advisors

### Le dashboard ne reçoit pas de signaux
- Vérifiez que l'EA affiche "Crystal Flask Bridge" dans l'onglet Journal
- Vérifiez que le serveur Flask est démarré
- Testez avec: `curl -X POST http://localhost:5000/api/signal -H "Content-Type: application/json" -d '{"symbol":"TEST","trend":"BULLISH"}'`

## 📜 Licence

Utilisation personnelle uniquement. L'indicateur Crystal Heikin Ashi est un produit commercial de Crystal Trading Systems.
