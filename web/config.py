"""
NMM System Toolkit - Web Intranet Edition
Configuration Settings

Copy this file to config_local.py and modify for your environment.
config_local.py is ignored by git.
"""

import os
from datetime import timedelta


class Config:
    """Base configuration"""

    # Application
    APP_NAME = 'NMM System Toolkit'
    VERSION = '8.0 Web'
    EDITION = 'Intranet Portal Edition'

    # Flask
    SECRET_KEY = os.environ.get('SECRET_KEY', 'change-this-in-production-use-strong-random-key')
    SESSION_TYPE = 'filesystem'
    PERMANENT_SESSION_LIFETIME = timedelta(hours=8)

    # PowerShell
    POWERSHELL_PATH = r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
    SCRIPT_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'NMMTools_v7.5_DEPLOYMENT_READY.ps1')

    # Authentication
    REQUIRE_AUTH = True
    ALLOWED_GROUPS = ['IT Administrators', 'Help Desk', 'Domain Admins']

    # Logging
    LOG_PATH = 'logs'
    LOG_LEVEL = 'INFO'

    # Job Management
    MAX_CONCURRENT_JOBS = 5
    JOB_TIMEOUT = 300  # seconds


class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True
    REQUIRE_AUTH = False  # Disable auth for development


class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False

    # Override with environment variables
    SECRET_KEY = os.environ.get('SECRET_KEY')

    # LDAP/Active Directory Settings
    LDAP_ENABLED = True
    LDAP_SERVER = os.environ.get('LDAP_SERVER', 'ldap://dc.company.local')
    LDAP_BASE_DN = os.environ.get('LDAP_BASE_DN', 'DC=company,DC=local')
    LDAP_USER_DN = os.environ.get('LDAP_USER_DN', 'CN=Users')
    LDAP_BIND_USER = os.environ.get('LDAP_BIND_USER')
    LDAP_BIND_PASSWORD = os.environ.get('LDAP_BIND_PASSWORD')

    # SSL/TLS
    SSL_ENABLED = True
    SSL_CERT = '/path/to/certificate.crt'
    SSL_KEY = '/path/to/private.key'


class TestingConfig(Config):
    """Testing configuration"""
    TESTING = True
    REQUIRE_AUTH = False


# Configuration dictionary
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}


def get_config():
    """Get configuration based on environment"""
    env = os.environ.get('FLASK_ENV', 'development')
    return config.get(env, config['default'])
