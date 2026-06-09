//! Configuration typée, chargée au démarrage. Défauts raisonnables surchargés
//! par variables d'environnement préfixées `APP_` (séparateur `__`).
//!
//! Exemples :
//!   APP_HTTP__PORT=9000
//!   APP_LOG__LEVEL=debug

use figment::{
    Figment,
    providers::{Env, Serialized},
};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub http: HttpConfig,
    pub log: LogConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HttpConfig {
    pub host: String,
    pub port: u16,
    /// Origines autorisées par CORS (ex : `https://app.exemple.com`).
    /// **Vide ⇒ mode permissif** (toute origine) : pratique en dev, à
    /// restreindre en prod. Surcharge via env (syntaxe liste figment) :
    /// `APP_HTTP__ALLOWED_ORIGINS=["https://app.exemple.com"]`.
    #[serde(default)]
    pub allowed_origins: Vec<String>,
    /// Délai max d'une requête avant `408 Request Timeout`. Borne les handlers
    /// lents/bloqués pour ne pas épuiser le pool de connexions.
    pub request_timeout_secs: u64,
    /// Taille max du corps de requête acceptée, en octets (anti-DoS).
    pub max_body_bytes: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogConfig {
    /// Filtre de log au format `tracing` (ex : "info", "debug,hyper=warn").
    pub level: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            http: HttpConfig {
                host: "0.0.0.0".to_owned(),
                port: 8080,
                allowed_origins: Vec::new(),
                request_timeout_secs: 30,
                max_body_bytes: 2 * 1024 * 1024, // 2 Mio
            },
            log: LogConfig {
                level: "info".to_owned(),
            },
        }
    }
}

impl Config {
    /// Charge la config : défauts + surcharges via l'environnement.
    ///
    /// # Errors
    /// Renvoie une erreur si une variable d'environnement a un type invalide
    /// (ex : `APP_HTTP__PORT=abc`).
    pub fn load() -> Result<Self, Box<figment::Error>> {
        Figment::from(Serialized::defaults(Config::default()))
            .merge(Env::prefixed("APP_").split("__"))
            .extract()
            .map_err(Box::new)
    }

    /// Adresse d'écoute `host:port`.
    #[must_use]
    pub fn http_addr(&self) -> String {
        format!("{}:{}", self.http.host, self.http.port)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_are_sane() {
        let cfg = Config::default();
        assert_eq!(cfg.http.port, 8080);
        assert_eq!(cfg.http_addr(), "0.0.0.0:8080");
    }
}
