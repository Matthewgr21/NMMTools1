"""
NMM System Toolkit - Web Intranet Edition
WSGI Entry Point for Production Deployment

Usage:
    gunicorn -w 4 -b 0.0.0.0:5000 wsgi:application

With SocketIO:
    gunicorn -k eventlet -w 1 -b 0.0.0.0:5000 wsgi:application
"""

import os
import sys

# Add the application directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import app, socketio

# For Gunicorn
application = app

if __name__ == '__main__':
    # Use socketio.run for WebSocket support
    socketio.run(
        app,
        host='0.0.0.0',
        port=int(os.environ.get('PORT', 5000)),
        debug=os.environ.get('FLASK_ENV') == 'development'
    )
