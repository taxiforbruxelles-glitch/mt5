"""
Crystal Heikin Ashi - Flask Bridge Application
Reçoit les signaux de l'indicateur MT5 et affiche un dashboard en temps réel
"""

from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
from datetime import datetime
import json
import sqlite3
import os

app = Flask(__name__)
app.config['SECRET_KEY'] = 'crystal_heikin_secret_2025'
socketio = SocketIO(app, cors_allowed_origins="*")

# Base de données pour stocker l'historique des signaux
DB_PATH = 'signals.db'

def init_db():
    """Initialise la base de données SQLite"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS signals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            symbol TEXT NOT NULL,
            timeframe TEXT NOT NULL,
            signal_type TEXT NOT NULL,
            ha_open REAL,
            ha_high REAL,
            ha_low REAL,
            ha_close REAL,
            trend TEXT,
            momentum_shift INTEGER DEFAULT 0,
            bid REAL,
            ask REAL,
            spread REAL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    c.execute('''
        CREATE TABLE IF NOT EXISTS trades (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            symbol TEXT NOT NULL,
            action TEXT NOT NULL,
            volume REAL,
            price REAL,
            sl REAL,
            tp REAL,
            status TEXT DEFAULT 'pending',
            ticket INTEGER,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    c.execute('''
        CREATE TABLE IF NOT EXISTS positions (
            ticket INTEGER PRIMARY KEY,
            symbol TEXT NOT NULL,
            type TEXT NOT NULL,
            volume REAL,
            open_price REAL,
            current_price REAL,
            sl REAL DEFAULT 0,
            tp REAL DEFAULT 0,
            profit REAL DEFAULT 0,
            open_time TEXT,
            status TEXT DEFAULT 'open',
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

def get_db():
    """Connexion à la base de données"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

# ============================================
# ROUTES API - Réception des signaux MT5
# ============================================

@app.route('/api/test', methods=['GET', 'POST'])
def test_connection():
    """Route de test pour vérifier la connexion"""
    return jsonify({'status': 'ok', 'message': 'Serveur Flask opérationnel'})

@app.route('/api/signal', methods=['POST'])
def receive_signal():
    """Reçoit un signal de l'EA MT5"""
    try:
        # Essayer différents formats de données
        data = None
        
        # JSON
        if request.is_json:
            data = request.get_json(silent=True)
        
        # Form data
        if data is None:
            data = request.form.to_dict()
        
        # Raw data (pour MT5 WebRequest)
        if not data or len(data) == 0:
            raw = request.get_data(as_text=True)
            print(f"[DEBUG] Raw data reçu: {raw[:500]}")
            
            # Parser le JSON manuellement
            import json
            try:
                # Nettoyer les caractères problématiques
                raw = raw.strip()
                if raw.startswith('{'):
                    data = json.loads(raw)
            except json.JSONDecodeError as e:
                print(f"[DEBUG] Erreur JSON: {e}")
                # Créer un signal minimal
                data = {'symbol': 'UNKNOWN', 'trend': 'NEUTRAL'}
        
        if not data:
            data = {}
        
        # Extraire les données avec valeurs par défaut
        signal = {
            'timestamp': data.get('timestamp', datetime.now().isoformat()),
            'symbol': data.get('symbol', 'UNKNOWN'),
            'timeframe': data.get('timeframe', 'M15'),
            'signal_type': data.get('signal_type', 'UPDATE'),
            'ha_open': float(data.get('ha_open', 0) or 0),
            'ha_high': float(data.get('ha_high', 0) or 0),
            'ha_low': float(data.get('ha_low', 0) or 0),
            'ha_close': float(data.get('ha_close', 0) or 0),
            'trend': data.get('trend', 'NEUTRAL'),
            'momentum_shift': int(data.get('momentum_shift', 0) or 0),
            'bid': float(data.get('bid', 0) or 0),
            'ask': float(data.get('ask', 0) or 0),
            'spread': float(data.get('spread', 0) or 0),
            # Indicateurs
            'resistance': float(data.get('resistance', 0) or 0),
            'support': float(data.get('support', 0) or 0),
            'supply_zone': float(data.get('supply_zone', 0) or 0),
            'demand_zone': float(data.get('demand_zone', 0) or 0),
            'vwap': float(data.get('vwap', 0) or 0),
            'vwap_upper': float(data.get('vwap_upper', 0) or 0),
            'vwap_lower': float(data.get('vwap_lower', 0) or 0),
            'poc': float(data.get('poc', 0) or 0),
            'harmonic_pattern': data.get('harmonic_pattern', 'NONE'),
            'price_position': data.get('price_position', 'NEUTRAL'),
            # Super Trend
            'supertrend_up': float(data.get('supertrend_up', 0) or 0),
            'supertrend_down': float(data.get('supertrend_down', 0) or 0),
            'supertrend_direction': data.get('supertrend_direction', 'NEUTRAL'),
            # Fibo Expansion
            'fibo_level1': float(data.get('fibo_level1', 0) or 0),
            'fibo_level2': float(data.get('fibo_level2', 0) or 0),
            'fibo_level3': float(data.get('fibo_level3', 0) or 0),
            # Nouveaux indicateurs
            'anchored_vwap': float(data.get('anchored_vwap', 0) or 0),
            'drawfib_level1': float(data.get('drawfib_level1', 0) or 0),
            'drawfib_level2': float(data.get('drawfib_level2', 0) or 0),
            'drawfib_level3': float(data.get('drawfib_level3', 0) or 0),
            'candle_pattern': data.get('candle_pattern', 'NONE'),
            'bollinger_signal': float(data.get('bollinger_signal', 0) or 0),
            'bollinger_direction': data.get('bollinger_direction', 'NEUTRAL'),
            'fvg_high': float(data.get('fvg_high', 0) or 0),
            'fvg_low': float(data.get('fvg_low', 0) or 0),
            'fvg_type': data.get('fvg_type', 'NONE'),
            'macd_main': float(data.get('macd_main', 0) or 0),
            'macd_signal': float(data.get('macd_signal', 0) or 0),
            'macd_trend': data.get('macd_trend', 'NEUTRAL'),
            'pro_resistance': float(data.get('pro_resistance', 0) or 0),
            'pro_support': float(data.get('pro_support', 0) or 0)
        }
        
        # =============================================
        # CALCUL DE CONFLUENCE
        # =============================================
        bullish_count = 0
        bearish_count = 0
        total_indicators = 0
        indicator_details = []
        
        # 1. Heikin Ashi Trend
        ha_trend = signal['trend']
        if ha_trend == 'BULLISH':
            bullish_count += 1
            indicator_details.append({'name': 'Heikin Ashi', 'signal': 'BULLISH', 'weight': 1})
        elif ha_trend == 'BEARISH':
            bearish_count += 1
            indicator_details.append({'name': 'Heikin Ashi', 'signal': 'BEARISH', 'weight': 1})
        else:
            indicator_details.append({'name': 'Heikin Ashi', 'signal': 'NEUTRAL', 'weight': 1})
        total_indicators += 1
        
        # 2. Super Trend
        st_dir = signal['supertrend_direction']
        if st_dir == 'BULLISH':
            bullish_count += 1
            indicator_details.append({'name': 'Super Trend', 'signal': 'BULLISH', 'weight': 1})
        elif st_dir == 'BEARISH':
            bearish_count += 1
            indicator_details.append({'name': 'Super Trend', 'signal': 'BEARISH', 'weight': 1})
        else:
            indicator_details.append({'name': 'Super Trend', 'signal': 'NEUTRAL', 'weight': 1})
        total_indicators += 1
        
        # 3. Harmonic Pattern
        harmonic = signal['harmonic_pattern']
        if harmonic == 'BULLISH':
            bullish_count += 1
            indicator_details.append({'name': 'Harmonic', 'signal': 'BULLISH', 'weight': 1})
        elif harmonic == 'BEARISH':
            bearish_count += 1
            indicator_details.append({'name': 'Harmonic', 'signal': 'BEARISH', 'weight': 1})
        elif harmonic not in ['NONE', '']:
            indicator_details.append({'name': 'Harmonic', 'signal': 'DETECTED', 'weight': 1})
        total_indicators += 1
        
        # 4. Prix vs Support/Resistance
        bid = signal['bid']
        support = signal['support']
        resistance = signal['resistance']
        if support > 0 and resistance > 0 and bid > 0:
            mid_point = (support + resistance) / 2
            if bid > mid_point:
                bullish_count += 1
                indicator_details.append({'name': 'Zone Position', 'signal': 'BULLISH', 'weight': 1})
            else:
                bearish_count += 1
                indicator_details.append({'name': 'Zone Position', 'signal': 'BEARISH', 'weight': 1})
            total_indicators += 1
        
        # 5. VWAP Position
        vwap = signal['vwap']
        if vwap > 0 and bid > 0:
            if bid > vwap:
                bullish_count += 1
                indicator_details.append({'name': 'VWAP', 'signal': 'BULLISH', 'weight': 1})
            else:
                bearish_count += 1
                indicator_details.append({'name': 'VWAP', 'signal': 'BEARISH', 'weight': 1})
            total_indicators += 1
        
        # 6. Momentum Shift (bonus)
        if signal['momentum_shift']:
            if ha_trend == 'BULLISH':
                bullish_count += 0.5
            elif ha_trend == 'BEARISH':
                bearish_count += 0.5
            indicator_details.append({'name': 'Momentum Shift', 'signal': ha_trend, 'weight': 0.5})
        
        # 7. Candlestick Patterns
        candle = signal['candle_pattern']
        if candle == 'BULLISH':
            bullish_count += 1
            indicator_details.append({'name': 'Candle Pattern', 'signal': 'BULLISH', 'weight': 1})
            total_indicators += 1
        elif candle == 'BEARISH':
            bearish_count += 1
            indicator_details.append({'name': 'Candle Pattern', 'signal': 'BEARISH', 'weight': 1})
            total_indicators += 1
        
        # 8. Bollinger RSI
        bollinger = signal['bollinger_direction']
        if bollinger == 'BULLISH':
            bullish_count += 1
            indicator_details.append({'name': 'Bollinger RSI', 'signal': 'BULLISH', 'weight': 1})
            total_indicators += 1
        elif bollinger == 'BEARISH':
            bearish_count += 1
            indicator_details.append({'name': 'Bollinger RSI', 'signal': 'BEARISH', 'weight': 1})
            total_indicators += 1
        
        # 9. FVG (Fair Value Gap)
        fvg = signal['fvg_type']
        if fvg == 'BULLISH':
            bullish_count += 1
            indicator_details.append({'name': 'FVG', 'signal': 'BULLISH', 'weight': 1})
            total_indicators += 1
        elif fvg == 'BEARISH':
            bearish_count += 1
            indicator_details.append({'name': 'FVG', 'signal': 'BEARISH', 'weight': 1})
            total_indicators += 1
        
        # 10. MACD Intraday
        macd = signal['macd_trend']
        if macd == 'BULLISH':
            bullish_count += 1
            indicator_details.append({'name': 'MACD', 'signal': 'BULLISH', 'weight': 1})
            total_indicators += 1
        elif macd == 'BEARISH':
            bearish_count += 1
            indicator_details.append({'name': 'MACD', 'signal': 'BEARISH', 'weight': 1})
            total_indicators += 1
        
        # 11. Pro Support Resistance Position
        pro_sup = signal['pro_support']
        pro_res = signal['pro_resistance']
        if pro_sup > 0 and pro_res > 0 and bid > 0:
            mid = (pro_sup + pro_res) / 2
            if bid > mid:
                bullish_count += 1
                indicator_details.append({'name': 'Pro S/R', 'signal': 'BULLISH', 'weight': 1})
            else:
                bearish_count += 1
                indicator_details.append({'name': 'Pro S/R', 'signal': 'BEARISH', 'weight': 1})
            total_indicators += 1
        
        # Calculer le score
        if total_indicators > 0:
            bullish_score = (bullish_count / total_indicators) * 100
            bearish_score = (bearish_count / total_indicators) * 100
        else:
            bullish_score = 0
            bearish_score = 0
        
        # Déterminer le signal final
        if bullish_score >= 80:
            final_signal = 'STRONG_BUY'
        elif bullish_score >= 60:
            final_signal = 'BUY'
        elif bearish_score >= 80:
            final_signal = 'STRONG_SELL'
        elif bearish_score >= 60:
            final_signal = 'SELL'
        else:
            final_signal = 'NEUTRAL'
        
        # Ajouter au signal
        signal['confluence'] = {
            'bullish_score': round(bullish_score, 1),
            'bearish_score': round(bearish_score, 1),
            'total_indicators': total_indicators,
            'bullish_count': bullish_count,
            'bearish_count': bearish_count,
            'final_signal': final_signal,
            'indicators': indicator_details
        }
        
        print(f"[CONFLUENCE] {signal['symbol']}: {final_signal} (Bull:{bullish_score:.0f}% Bear:{bearish_score:.0f}%)")
        
        # Sauvegarder en base
        conn = get_db()
        c = conn.cursor()
        c.execute('''
            INSERT INTO signals (timestamp, symbol, timeframe, signal_type, 
                ha_open, ha_high, ha_low, ha_close, trend, momentum_shift, bid, ask, spread)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (signal['timestamp'], signal['symbol'], signal['timeframe'], 
              signal['signal_type'], signal['ha_open'], signal['ha_high'],
              signal['ha_low'], signal['ha_close'], signal['trend'],
              signal['momentum_shift'], signal['bid'], signal['ask'], signal['spread']))
        conn.commit()
        conn.close()
        
        # Diffuser via WebSocket
        socketio.emit('new_signal', signal)
        
        # Log
        print(f"[SIGNAL] {signal['symbol']} | {signal['trend']} | Momentum Shift: {signal['momentum_shift']}")
        
        return jsonify({'status': 'success', 'signal': signal})
    
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/trade', methods=['POST'])
def send_trade_command():
    """Envoie une commande de trade à MT5"""
    try:
        data = request.get_json() or request.form.to_dict()
        
        symbol = data.get('symbol', '')
        if not symbol or symbol == 'UNKNOWN' or symbol == '--':
            return jsonify({'status': 'error', 'message': 'Symbole invalide'}), 400
        
        trade = {
            'timestamp': datetime.now().isoformat(),
            'symbol': symbol,
            'action': data.get('action'),  # BUY, SELL, CLOSE
            'volume': float(data.get('volume', 0.01) or 0.01),
            'price': float(data.get('price', 0) or 0),
            'sl': float(data.get('sl', 0) or 0),
            'tp': float(data.get('tp', 0) or 0),
            'status': 'pending'
        }
        
        # Sauvegarder la commande
        conn = get_db()
        c = conn.cursor()
        c.execute('''
            INSERT INTO trades (timestamp, symbol, action, volume, price, sl, tp, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (trade['timestamp'], trade['symbol'], trade['action'], 
              trade['volume'], trade['price'], trade['sl'], trade['tp'], trade['status']))
        trade_id = c.lastrowid
        conn.commit()
        conn.close()
        
        trade['id'] = trade_id
        
        # Diffuser pour que l'EA récupère
        socketio.emit('trade_command', trade)
        
        print(f"[TRADE] Nouvelle commande #{trade_id}: {trade['action']} {trade['symbol']} {trade['volume']} lots")
        
        return jsonify({'status': 'success', 'trade': trade})
    
    except Exception as e:
        print(f"[ERROR] send_trade: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/pending_trades', methods=['GET'])
def get_pending_trades():
    """L'EA récupère les trades en attente"""
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM trades WHERE status = 'pending' ORDER BY created_at ASC")
    rows = c.fetchall()
    trades = []
    for row in rows:
        trade = dict(row)
        # S'assurer que le ticket est bien un entier
        if trade.get('ticket'):
            trade['ticket'] = int(trade['ticket'])
        trades.append(trade)
    conn.close()
    
    if trades:
        print(f"[PENDING] {len(trades)} trades en attente:")
        for t in trades:
            print(f"  - ID={t['id']} Action={t['action']} Ticket={t.get('ticket')} Symbol={t.get('symbol')}")
    
    return jsonify({'trades': trades})

@app.route('/api/confirm_trade/<int:trade_id>', methods=['POST'])
def confirm_trade(trade_id):
    """L'EA confirme l'exécution d'un trade"""
    try:
        # Essayer différents formats
        data = None
        if request.is_json:
            data = request.get_json(silent=True)
        
        if data is None:
            data = request.form.to_dict()
        
        if not data or len(data) == 0:
            raw = request.get_data(as_text=True)
            if raw:
                import json
                try:
                    data = json.loads(raw)
                except:
                    data = {}
        
        if not data:
            data = {}
        
        status = data.get('status', 'executed')
        ticket = data.get('ticket', 0)
        
        conn = get_db()
        c = conn.cursor()
        c.execute('''
            UPDATE trades SET status = ?, ticket = ? WHERE id = ?
        ''', (status, ticket, trade_id))
        conn.commit()
        conn.close()
        
        socketio.emit('trade_update', {'id': trade_id, 'status': status})
        print(f"[TRADE] Confirmé #{trade_id} - Status: {status}, Ticket: {ticket}")
        
        return jsonify({'status': 'success'})
    
    except Exception as e:
        print(f"[ERROR] confirm_trade: {str(e)}")
        # Même en cas d'erreur, marquer comme traité pour éviter la boucle
        try:
            conn = get_db()
            c = conn.cursor()
            c.execute("UPDATE trades SET status = 'error' WHERE id = ?", (trade_id,))
            conn.commit()
            conn.close()
        except:
            pass
        return jsonify({'status': 'error', 'message': str(e)}), 400

# ============================================
# ROUTES DASHBOARD
# ============================================

@app.route('/')
def dashboard():
    """Page principale du dashboard"""
    return render_template('dashboard.html')

@app.route('/api/signals/history')
def get_signals_history():
    """Récupère l'historique des signaux"""
    limit = request.args.get('limit', 100, type=int)
    symbol = request.args.get('symbol', None)
    
    conn = get_db()
    c = conn.cursor()
    
    if symbol:
        c.execute('''
            SELECT * FROM signals WHERE symbol = ? 
            ORDER BY created_at DESC LIMIT ?
        ''', (symbol, limit))
    else:
        c.execute('SELECT * FROM signals ORDER BY created_at DESC LIMIT ?', (limit,))
    
    signals = [dict(row) for row in c.fetchall()]
    conn.close()
    
    return jsonify({'signals': signals})

@app.route('/api/stats')
def get_stats():
    """Statistiques globales"""
    conn = get_db()
    c = conn.cursor()
    
    # Compter les signaux par tendance
    c.execute('''
        SELECT trend, COUNT(*) as count FROM signals 
        WHERE created_at > datetime('now', '-24 hours')
        GROUP BY trend
    ''')
    trend_stats = {row['trend']: row['count'] for row in c.fetchall()}
    
    # Compter les momentum shifts
    c.execute('''
        SELECT COUNT(*) as count FROM signals 
        WHERE momentum_shift = 1 AND created_at > datetime('now', '-24 hours')
    ''')
    momentum_shifts = c.fetchone()['count']
    
    # Dernier signal par symbole
    c.execute('''
        SELECT symbol, trend, momentum_shift, bid, ask, timestamp 
        FROM signals 
        GROUP BY symbol 
        ORDER BY created_at DESC
    ''')
    latest_by_symbol = [dict(row) for row in c.fetchall()]
    
    conn.close()
    
    return jsonify({
        'trend_stats': trend_stats,
        'momentum_shifts_24h': momentum_shifts,
        'latest_by_symbol': latest_by_symbol
    })

# ============================================
# ROUTES POSITIONS & ACCOUNT
# ============================================

@app.route('/api/positions', methods=['GET'])
def get_positions():
    """Récupère les positions ouvertes depuis MT5"""
    conn = get_db()
    c = conn.cursor()
    c.execute('''
        SELECT * FROM positions WHERE status = 'open' ORDER BY open_time DESC
    ''')
    positions = [dict(row) for row in c.fetchall()]
    conn.close()
    return jsonify({'positions': positions})

@app.route('/api/positions/update', methods=['POST'])
def update_positions():
    """L'EA envoie les positions ouvertes"""
    try:
        data = None
        if request.is_json:
            data = request.get_json(silent=True)
        if data is None:
            raw = request.get_data(as_text=True)
            if raw:
                import json
                data = json.loads(raw)
        
        if not data:
            return jsonify({'status': 'error', 'message': 'No data'}), 400
        
        positions = data.get('positions', [])
        
        conn = get_db()
        c = conn.cursor()
        
        # Marquer toutes les positions comme fermées
        c.execute("UPDATE positions SET status = 'closed' WHERE status = 'open'")
        
        # Mettre à jour ou insérer les positions actuelles
        for pos in positions:
            c.execute('''
                INSERT OR REPLACE INTO positions 
                (ticket, symbol, type, volume, open_price, current_price, sl, tp, profit, open_time, status)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'open')
            ''', (
                pos.get('ticket'),
                pos.get('symbol'),
                pos.get('type'),
                pos.get('volume'),
                pos.get('open_price'),
                pos.get('current_price'),
                pos.get('sl', 0),
                pos.get('tp', 0),
                pos.get('profit', 0),
                pos.get('open_time', datetime.now().isoformat())
            ))
        
        conn.commit()
        conn.close()
        
        # Diffuser via WebSocket
        socketio.emit('positions_update', {'positions': positions})
        
        return jsonify({'status': 'success', 'count': len(positions)})
    
    except Exception as e:
        print(f"[ERROR] update_positions: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/account', methods=['POST'])
def update_account():
    """L'EA envoie les infos du compte"""
    try:
        data = None
        if request.is_json:
            data = request.get_json(silent=True)
        if data is None:
            raw = request.get_data(as_text=True)
            if raw:
                import json
                data = json.loads(raw)
        
        if data:
            socketio.emit('account_update', {
                'balance': data.get('balance', 0),
                'equity': data.get('equity', 0),
                'margin': data.get('margin', 0),
                'freeMargin': data.get('free_margin', 0)
            })
        
        return jsonify({'status': 'success'})
    
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/close_position', methods=['POST'])
def close_position():
    """Demande de fermeture d'une position"""
    try:
        data = request.get_json() or {}
        ticket = data.get('ticket')
        
        if not ticket:
            return jsonify({'status': 'error', 'message': 'Ticket requis'}), 400
        
        # Convertir en int
        ticket = int(ticket)
        
        # Ajouter la commande de fermeture avec le ticket dans plusieurs champs pour être sûr
        conn = get_db()
        c = conn.cursor()
        # Le ticket est dans la colonne 'ticket' ET dans 'symbol' comme backup
        c.execute('''
            INSERT INTO trades (timestamp, symbol, action, volume, price, sl, tp, status, ticket)
            VALUES (?, ?, 'CLOSE', 0, 0, 0, 0, 'pending', ?)
        ''', (datetime.now().isoformat(), str(ticket), ticket))
        trade_id = c.lastrowid
        conn.commit()
        
        # Vérifier l'insertion
        c.execute("SELECT * FROM trades WHERE id = ?", (trade_id,))
        row = c.fetchone()
        conn.close()
        
        print(f"[TRADE] Demande fermeture position #{ticket}")
        if row:
            print(f"[DEBUG] Trade inséré ID={trade_id}: action={row['action']}, ticket={row['ticket']}, symbol={row['symbol']}")
        
        return jsonify({'status': 'success', 'ticket': ticket, 'trade_id': trade_id})
    
    except Exception as e:
        print(f"[ERROR] close_position: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/close_all', methods=['POST'])
def close_all_positions():
    """Demande de fermeture de toutes les positions"""
    try:
        conn = get_db()
        c = conn.cursor()
        c.execute('''
            INSERT INTO trades (timestamp, symbol, action, volume, status)
            VALUES (?, '', 'CLOSE_ALL', 0, 'pending')
        ''', (datetime.now().isoformat(),))
        conn.commit()
        conn.close()
        
        print("[TRADE] Demande fermeture TOUTES les positions")
        
        return jsonify({'status': 'success', 'closed': 'pending'})
    
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/modify_position', methods=['POST'])
def modify_position():
    """Demande de modification d'une position (SL/TP)"""
    try:
        data = request.get_json() or {}
        ticket = data.get('ticket')
        new_sl = data.get('sl')
        new_tp = data.get('tp')
        
        if not ticket:
            return jsonify({'status': 'error', 'message': 'Ticket requis'}), 400
        
        # Créer la commande de modification
        modify_data = {'ticket': ticket}
        if new_sl is not None:
            modify_data['sl'] = new_sl
        if new_tp is not None:
            modify_data['tp'] = new_tp
        
        conn = get_db()
        c = conn.cursor()
        c.execute('''
            INSERT INTO trades (timestamp, symbol, action, volume, sl, tp, status, ticket)
            VALUES (?, ?, 'MODIFY', 0, ?, ?, 'pending', ?)
        ''', (datetime.now().isoformat(), str(ticket), new_sl or 0, new_tp or 0, int(ticket)))
        conn.commit()
        conn.close()
        
        print(f"[TRADE] Demande modification position #{ticket} - SL: {new_sl}, TP: {new_tp}")
        
        return jsonify({'status': 'success'})
    
    except Exception as e:
        print(f"[ERROR] modify_position: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/cancel_trade/<int:trade_id>', methods=['POST'])
def cancel_trade(trade_id):
    """Annuler un trade en attente (supprimer de la queue)"""
    try:
        conn = get_db()
        c = conn.cursor()
        c.execute("UPDATE trades SET status = 'cancelled' WHERE id = ? AND status = 'pending'", (trade_id,))
        affected = c.rowcount
        conn.commit()
        conn.close()
        
        if affected > 0:
            print(f"[TRADE] Trade #{trade_id} annulé")
            return jsonify({'status': 'success', 'message': f'Trade #{trade_id} annulé'})
        else:
            return jsonify({'status': 'error', 'message': 'Trade non trouvé ou déjà traité'}), 404
    
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

@app.route('/api/pending_trades_list', methods=['GET'])
def pending_trades_list():
    """Liste les trades en attente pour affichage dans le dashboard"""
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM trades WHERE status = 'pending' ORDER BY created_at DESC")
    trades = [dict(row) for row in c.fetchall()]
    conn.close()
    return jsonify({'trades': trades})

@app.route('/api/clear_pending', methods=['POST'])
def clear_pending():
    """Supprimer tous les trades en attente"""
    try:
        conn = get_db()
        c = conn.cursor()
        c.execute("UPDATE trades SET status = 'cancelled' WHERE status = 'pending'")
        count = c.rowcount
        conn.commit()
        conn.close()
        print(f"[TRADE] {count} trades en attente annulés")
        return jsonify({'status': 'success', 'cleared': count})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400
        
        conn = get_db()
        c = conn.cursor()
        c.execute('''
            INSERT INTO trades (timestamp, symbol, action, volume, status, ticket, sl, tp)
            VALUES (?, '', 'MODIFY', 0, 'pending', ?, ?, ?)
        ''', (datetime.now().isoformat(), ticket, new_sl or 0, new_tp or 0))
        conn.commit()
        conn.close()
        
        print(f"[TRADE] Demande modification position #{ticket} - SL: {new_sl}, TP: {new_tp}")
        
        return jsonify({'status': 'success'})
    
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400

# ============================================
# WEBSOCKET EVENTS
# ============================================

@socketio.on('connect')
def handle_connect():
    print('[WS] Client connecté')
    emit('connected', {'status': 'ok', 'message': 'Connecté au serveur Crystal Heikin'})

@socketio.on('disconnect')
def handle_disconnect():
    print('[WS] Client déconnecté')

@socketio.on('subscribe')
def handle_subscribe(data):
    """Abonnement à un symbole spécifique"""
    symbol = data.get('symbol', 'ALL')
    print(f'[WS] Abonnement: {symbol}')
    emit('subscribed', {'symbol': symbol})

# ============================================
# MAIN
# ============================================

if __name__ == '__main__':
    init_db()
    print("=" * 50)
    print("Crystal Heikin Ashi - Flask Bridge")
    print("=" * 50)
    print("Server démarré sur http://localhost:5000")
    print("En attente des signaux MT5...")
    print("=" * 50)
    socketio.run(app, host='0.0.0.0', port=5000, debug=True, allow_unsafe_werkzeug=True)
